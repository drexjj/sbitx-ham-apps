#include "SBITXDevice.hpp"
#include <SoapySDR/Logger.hpp>
#include <SoapySDR/Formats.hpp>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <sstream>
#include <cstring>

#ifdef __linux__
#include <pthread.h>
#include <sched.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#endif

SBITXDevice::SBITXDevice(const SoapySDR::Kwargs &args)
{
    alsaCapDev_ = args.count("alsa") ? args.at("alsa") : "hw:0,0";

    // IQ output rate
    fs_ = 48000;

    // WM8731 capture rate
    capFs_ = 96000;

    // IF offset (Hz) — same idea as your Quisk bridge
    ifHz_ = args.count("if") ? std::stod(args.at("if")) : 24000.0;

    iqSwap_ = args.count("iq_swap") ? (std::stoi(args.at("iq_swap")) != 0) : false;
    periodFrames_ = args.count("period") ? (snd_pcm_uframes_t)std::stoul(args.at("period")) : 1000;
    bufferFrames_ = args.count("buffer") ? (snd_pcm_uframes_t)std::stoul(args.at("buffer")) : 4000;
    rt_ = args.count("rt") ? (std::stoi(args.at("rt")) != 0) : false;
    rtPrio_ = args.count("rt_prio") ? std::stoi(args.at("rt_prio")) : 70;

    // sbitx_ctrl TCP
    ctrlHost_ = args.count("ctrl_host") ? args.at("ctrl_host") : "127.0.0.1";
    ctrlPort_ = args.count("ctrl_port") ? std::stoi(args.at("ctrl_port")) : 9999;

    rbSize_ = fs_ * 2; // 2 seconds
    rb_.assign(rbSize_, std::complex<float>(0,0));

    SoapySDR::logf(SOAPY_SDR_INFO,
        "SBITX: alsa=%s fs=%u capFs=%u if=%.1f iq_swap=%d period=%lu buffer=%lu rt=%d ctrl=%s:%d",
        alsaCapDev_.c_str(), fs_, capFs_, ifHz_, (int)iqSwap_,
        (unsigned long)periodFrames_, (unsigned long)bufferFrames_, (int)rt_,
        ctrlHost_.c_str(), ctrlPort_);
}

SBITXDevice::~SBITXDevice()
{
    stopRxThread();
    closeAlsaCapture();
}

SoapySDR::Kwargs SBITXDevice::getHardwareInfo() const
{
    SoapySDR::Kwargs info;
    info["origin"] = "sbitx";
    info["alsa_capture"] = alsaCapDev_;
    info["fs"] = std::to_string(fs_);
    info["cap_fs"] = std::to_string(capFs_);
    info["if_hz"] = std::to_string(ifHz_);
    info["ctrl_host"] = ctrlHost_;
    info["ctrl_port"] = std::to_string(ctrlPort_);
    return info;
}

std::vector<double> SBITXDevice::listSampleRates(const int, const size_t) const
{
    return { 48000.0 };
}

void SBITXDevice::setSampleRate(const int, const size_t, const double rate)
{
    if (std::llround(rate) != 48000)
        throw std::runtime_error("SBITX: only 48000 sps supported (driver decimates from 96k capture)");
}

double SBITXDevice::getSampleRate(const int, const size_t) const
{
    return 48000.0;
}

void SBITXDevice::setFrequency(const int, const size_t, const std::string &name,
                               const double frequency, const SoapySDR::Kwargs &)
{
    if (name != "RF") return;

    // App-visible RF (what CubicSDR shows)
    tuneHz_ = frequency;

    // Hardware is tuned to (RF - IF) so the desired RF appears centered in the IF passband.
    const long long hwHz = (long long)std::llround(frequency - ifHz_);

    if (!ctrlSetHwFreqHz(hwHz))
    {
        SoapySDR::logf(SOAPY_SDR_WARNING, "SBITX: setFrequency failed to set HW freq to %lld Hz via %s:%d",
                       hwHz, ctrlHost_.c_str(), ctrlPort_);
    }
}

double SBITXDevice::getFrequency(const int, const size_t, const std::string &name) const
{
    if (name != "RF") return 0.0;

    // Read HW freq from sbitx_ctrl and convert back to RF by adding IF.
    long long hwHz = 0;
    if (ctrlGetHwFreqHz(hwHz))
    {
        tuneHz_ = (double)hwHz + ifHz_;
    }
    return tuneHz_;
}

std::vector<std::string> SBITXDevice::getStreamFormats(const int, const size_t) const
{
    return { SOAPY_SDR_CF32 };
}

std::string SBITXDevice::getNativeStreamFormat(const int, const size_t, double &fullScale) const
{
    fullScale = 1.0;
    return SOAPY_SDR_CF32;
}

SoapySDR::Stream *SBITXDevice::setupStream(const int direction, const std::string &format,
                                           const std::vector<size_t> &channels,
                                           const SoapySDR::Kwargs &)
{
    if (direction != SOAPY_SDR_RX) throw std::runtime_error("SBITX: RX only (Level 2)");
    if (format != SOAPY_SDR_CF32) throw std::runtime_error("SBITX: only CF32 supported");
    if (!channels.empty() && channels.at(0) != 0) throw std::runtime_error("SBITX: only channel 0");

    if (!openAlsaCapture()) throw std::runtime_error("SBITX: ALSA capture open failed");
    return reinterpret_cast<SoapySDR::Stream*>(new RxStream{0});
}

void SBITXDevice::closeStream(SoapySDR::Stream *stream)
{
    stopRxThread();
    closeAlsaCapture();
    delete reinterpret_cast<RxStream*>(stream);
}

int SBITXDevice::activateStream(SoapySDR::Stream *, const int, const long long, const size_t)
{
    startRxThread();
    return 0;
}

int SBITXDevice::deactivateStream(SoapySDR::Stream *, const int, const long long)
{
    stopRxThread();
    return 0;
}

int SBITXDevice::readStream(SoapySDR::Stream *, void * const *buffs, const size_t numElems,
                            int &flags, long long &timeNs, const long timeoutUs)
{
    flags = 0; timeNs = 0;
    auto *out = reinterpret_cast<std::complex<float>*>(buffs[0]);

    const auto t0 = std::chrono::steady_clock::now();
    while (true)
    {
        size_t got = rbRead(out, numElems);
        if (got) return (int)got;

        std::this_thread::sleep_for(std::chrono::microseconds(200));
        auto dt = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-t0).count();
        if (dt > timeoutUs) return SOAPY_SDR_TIMEOUT;
    }
}

bool SBITXDevice::openAlsaCapture()
{
    if (capHandle_) return true;

    int rc = snd_pcm_open(&capHandle_, alsaCapDev_.c_str(), SND_PCM_STREAM_CAPTURE, 0);
    if (rc < 0)
    {
        SoapySDR::logf(SOAPY_SDR_ERROR, "snd_pcm_open CAP failed: %s", snd_strerror(rc));
        capHandle_ = nullptr;
        return false;
    }

    snd_pcm_hw_params_t *hw;
    snd_pcm_hw_params_alloca(&hw);
    snd_pcm_hw_params_any(capHandle_, hw);
    snd_pcm_hw_params_set_access(capHandle_, hw, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(capHandle_, hw, SND_PCM_FORMAT_S32_LE);
    snd_pcm_hw_params_set_channels(capHandle_, hw, 2);

    unsigned int rate = capFs_;
    snd_pcm_hw_params_set_rate_near(capHandle_, hw, &rate, nullptr);

    snd_pcm_hw_params_set_period_size_near(capHandle_, hw, &periodFrames_, nullptr);
    snd_pcm_hw_params_set_buffer_size_near(capHandle_, hw, &bufferFrames_);

    rc = snd_pcm_hw_params(capHandle_, hw);
    if (rc < 0)
    {
        SoapySDR::logf(SOAPY_SDR_ERROR, "snd_pcm_hw_params failed: %s", snd_strerror(rc));
        snd_pcm_close(capHandle_);
        capHandle_ = nullptr;
        return false;
    }

    snd_pcm_prepare(capHandle_);
    return true;
}

void SBITXDevice::closeAlsaCapture()
{
    if (!capHandle_) return;
    snd_pcm_drop(capHandle_);
    snd_pcm_close(capHandle_);
    capHandle_ = nullptr;
}

void SBITXDevice::startRxThread()
{
    if (rxRun_.exchange(true)) return;
    rxThread_ = std::thread(&SBITXDevice::rxThreadMain, this);
}

void SBITXDevice::stopRxThread()
{
    if (!rxRun_.exchange(false)) return;
    if (rxThread_.joinable()) rxThread_.join();
}

void SBITXDevice::rbWrite(const std::complex<float>* in, size_t n)
{
    std::lock_guard<std::mutex> lock(rbMutex_);
    for (size_t i = 0; i < n; i++)
    {
        rb_[rbHead_] = in[i];
        rbHead_ = (rbHead_ + 1) % rbSize_;
        if (rbHead_ == rbTail_) rbTail_ = (rbTail_ + 1) % rbSize_;
    }
}

size_t SBITXDevice::rbRead(std::complex<float>* out, size_t n)
{
    std::lock_guard<std::mutex> lock(rbMutex_);
    size_t count = 0;
    while (count < n && rbTail_ != rbHead_)
    {
        out[count++] = rb_[rbTail_];
        rbTail_ = (rbTail_ + 1) % rbSize_;
    }
    return count;
}

void SBITXDevice::rxThreadMain()
{
#ifdef __linux__
    if (rt_)
    {
        struct sched_param sp{};
        sp.sched_priority = rtPrio_;
        if (pthread_setschedparam(pthread_self(), SCHED_FIFO, &sp) != 0)
            SoapySDR::logf(SOAPY_SDR_WARNING,
                "SBITX: failed to set RT scheduling (SCHED_FIFO). Try running as root or with CAP_SYS_NICE.");
    }
#endif

    if (!openAlsaCapture())
    {
        SoapySDR::logf(SOAPY_SDR_ERROR, "SBITX: ALSA capture open failed for %s", alsaCapDev_.c_str());
        return;
    }

    // WM8731 @ 96k stereo S32_LE:
    //   Left  = IF audio (real)
    //   Right = MIC (ignored here)
    //
    // Create complex IQ from IF(left) by mixing down at ifHz_ and decimating 96k -> 48k.

    const double w = 2.0 * M_PI * (ifHz_ / capFs_);
    double ph = phase_;

    const snd_pcm_uframes_t chunk = (periodFrames_ % 2 == 0) ? periodFrames_ : (periodFrames_ + 1);

    std::vector<int32_t> buf((size_t)chunk * 2);
    std::vector<std::complex<float>> out((size_t)chunk / 2);

    while (rxRun_)
    {
        snd_pcm_sframes_t n = snd_pcm_readi(capHandle_, buf.data(), chunk);
        if (n == -EPIPE)
        {
            snd_pcm_prepare(capHandle_);
            continue;
        }
        if (n < 0)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
            continue;
        }

        if (n & 1) n--;

        const float scale = 1.0f / 2147483648.0f;
        size_t o = 0;

        for (snd_pcm_sframes_t i = 0; i < n; i += 2)
        {
            const float x0 = (float)buf[(size_t)i * 2 + 0] * scale;       // L
            const float x1 = (float)buf[(size_t)(i + 1) * 2 + 0] * scale; // L

            float c0 = (float)std::cos(ph);
            float s0 = (float)std::sin(ph);
            std::complex<float> z0(x0 * c0, -x0 * s0);
            ph += w; if (ph > M_PI) ph -= 2.0 * M_PI;

            float c1 = (float)std::cos(ph);
            float s1 = (float)std::sin(ph);
            std::complex<float> z1(x1 * c1, -x1 * s1);
            ph += w; if (ph > M_PI) ph -= 2.0 * M_PI;

            std::complex<float> y = 0.5f * (z0 + z1);

            float I = y.real();
            float Q = y.imag();
            if (iqSwap_) std::swap(I, Q);
            out[o++] = {I, Q};
        }

        if (o) rbWrite(out.data(), o);
    }

    phase_ = ph;
}

// ----------------------- sbitx_ctrl TCP control -----------------------

bool SBITXDevice::tcpSendRecvLine(const std::string &lineToSend, std::string &replyLine) const
{
#ifdef __linux__
    replyLine.clear();

    int fd = ::socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return false;

    struct sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)ctrlPort_);

    // try dotted-quad first
    if (::inet_pton(AF_INET, ctrlHost_.c_str(), &addr.sin_addr) != 1)
    {
        // fallback: DNS resolve
        struct hostent *he = ::gethostbyname(ctrlHost_.c_str());
        if (!he)
        {
            ::close(fd);
            return false;
        }
        std::memcpy(&addr.sin_addr, he->h_addr_list[0], he->h_length);
    }

    if (::connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0)
    {
        ::close(fd);
        return false;
    }

    // send
    const std::string msg = lineToSend;
    ssize_t wr = ::send(fd, msg.c_str(), msg.size(), 0);
    if (wr < 0)
    {
        ::close(fd);
        return false;
    }

    // recv until newline (or EOF)
    char buf[256];
    while (true)
    {
        ssize_t rd = ::recv(fd, buf, sizeof(buf)-1, 0);
        if (rd <= 0) break;
        buf[rd] = 0;
        replyLine += buf;
        if (replyLine.find('\n') != std::string::npos) break;
    }

    ::close(fd);

    // keep only first line
    auto pos = replyLine.find('\n');
    if (pos != std::string::npos) replyLine.resize(pos);

    // trim CR
    if (!replyLine.empty() && replyLine.back() == '\r') replyLine.pop_back();
    return !replyLine.empty();
#else
    (void)lineToSend; (void)replyLine;
    return false;
#endif
}

bool SBITXDevice::ctrlSetHwFreqHz(long long hz) const
{
    std::string reply;
    std::ostringstream ss;
    ss << "F " << hz << "\n";
    if (!tcpSendRecvLine(ss.str(), reply)) return false;

    // expected: "OK <hz>" (or similar). We accept anything non-empty as success.
    return true;
}

bool SBITXDevice::ctrlGetHwFreqHz(long long &hz) const
{
    std::string reply;
    if (!tcpSendRecvLine(std::string("f\n"), reply)) return false;

    // expected: "<hz>"
    try {
        hz = std::stoll(reply);
        return true;
    } catch (...) {
        return false;
    }
}
