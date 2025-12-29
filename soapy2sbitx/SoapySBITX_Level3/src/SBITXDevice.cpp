#include "SBITXDevice.hpp"

#include <SoapySDR/Logger.hpp>
#include <SoapySDR/Formats.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <thread>
#include <climits>

#ifdef __linux__
#include <pthread.h>
#include <sched.h>
#include <netdb.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

static inline float dbToLin(double db)
{
    return std::pow(10.0, db / 20.0);
}
static inline int32_t float_to_s32(float x)
{
    x = std::max(-1.0f, std::min(0.999999f, x));
    const float scale = 2147483647.0f;
    return (int32_t)std::lrintf(x * scale);
}

static inline float s32_to_float(int32_t x)
{
    return (float)x / 2147483647.0f;
}

SBITXDevice::SBITXDevice(const SoapySDR::Kwargs &args)
{
    alsaDev_ = args.count("alsa") ? args.at("alsa") : "hw:0,0";

    fs_ = 48000;
    capFs_ = args.count("capFs") ? (unsigned int)std::stoul(args.at("capFs")) : 96000;
    pbFs_  = args.count("pbFs")  ? (unsigned int)std::stoul(args.at("pbFs"))  : 96000;

    ifHz_ = args.count("if") ? std::stod(args.at("if")) : 24000.0;
    iqSwap_ = args.count("iq_swap") ? (std::stoi(args.at("iq_swap")) != 0) : false;

    iqInv_  = args.count("iq_inv") ? (std::stoi(args.at("iq_inv")) != 0) : false;
    periodFrames_ = args.count("period") ? (snd_pcm_uframes_t)std::stoul(args.at("period")) : 1000;
    bufferFrames_ = args.count("buffer") ? (snd_pcm_uframes_t)std::stoul(args.at("buffer")) : 4000;

    rt_ = args.count("rt") ? (std::stoi(args.at("rt")) != 0) : false;
    rtPrio_ = args.count("rt_prio") ? std::stoi(args.at("rt_prio")) : 70;

    // ctrl can be:
    //   ctrl=127.0.0.1:9999   (default)
    //   ctrl=none             (disable)
    if (args.count("ctrl"))
    {
        const std::string c = args.at("ctrl");
        if (c == "none" || c == "0")
        {
            ctrlEnabled_ = false;
        }
        else
        {
            auto pos = c.find(':');
            if (pos != std::string::npos)
            {
                ctrlHost_ = c.substr(0, pos);
                ctrlPort_ = std::stoi(c.substr(pos + 1));
                ctrlEnabled_ = true;
            }
        }
    }

    rbSize_ = fs_ * 2; // 2 seconds ring buffer @48k
    rb_.assign(rbSize_, std::complex<float>(0, 0));

    SoapySDR::logf(SOAPY_SDR_INFO,
        "SBITX: alsa=%s fs=%u capFs=%u pbFs=%u if=%.1f iq_swap=%d iq_inv=%d period=%lu buffer=%lu rt=%d ctrl=%s:%d (%s)",
        alsaDev_.c_str(), fs_, capFs_, pbFs_, ifHz_, (int)iqSwap_, (int)iqInv_,
        (unsigned long)periodFrames_, (unsigned long)bufferFrames_, (int)rt_,
        ctrlHost_.c_str(), ctrlPort_, ctrlEnabled_ ? "on" : "off");
}

SBITXDevice::~SBITXDevice()
{
    stopRxThread();
    closeAlsaCapture();
    closeAlsaPlayback();
}

SoapySDR::Kwargs SBITXDevice::getHardwareInfo() const
{
    SoapySDR::Kwargs info;
    info["origin"] = "sbitx";
    info["alsa_capture"] = alsaDev_;
    info["alsa_playback"] = alsaDev_;
    info["fs"] = std::to_string(fs_);
    info["cap_fs"] = std::to_string(capFs_);
    info["pb_fs"] = std::to_string(pbFs_);
    info["if_hz"] = std::to_string(ifHz_);
    info["ctrl_host"] = ctrlHost_;
    info["ctrl_port"] = std::to_string(ctrlPort_);
    return info;
}

std::vector<double> SBITXDevice::listSampleRates(const int, const size_t) const
{
    return { 48000.0 };
}
std::vector<std::string> SBITXDevice::listFrequencies(const int, const size_t) const
{
    // piHPSDR expects "RF" to exist
    return {"RF"};
}

SoapySDR::RangeList SBITXDevice::getFrequencyRange(const int, const size_t, const std::string &name) const
{
    SoapySDR::RangeList r;
    if (name != "RF") return r;

    // Be generous so piHPSDR is happy (HF through VHF etc).
    // You can tighten later if you want.
    r.push_back(SoapySDR::Range(0.0, 600e6));
    return r;
}

std::vector<std::string> SBITXDevice::listGains(const int direction, const size_t) const
{
    if (direction == SOAPY_SDR_TX) return {"PA"};
    return {};
}
std::atomic<float> txPaGain_{255.0f}; //default full drive
SoapySDR::Range SBITXDevice::getGainRange(
    const int direction,
    const size_t,
    const std::string &name) const
{
    if (direction == SOAPY_SDR_TX && name == "PA")
        return SoapySDR::Range(0.0, 100.0);
    return SoapySDR::Range();
}

double SBITXDevice::getGain(
    const int direction,
    const size_t,
    const std::string &name) const

{
    if (direction == SOAPY_SDR_TX && name == "PA")
        return (double)txPaGain_.load(std::memory_order_relaxed); // store raw 0..255
    return 0.0;
}

void SBITXDevice::setGain(
    const int direction,
    const size_t,
    const std::string &name,
    const double value)
{
    if (direction == SOAPY_SDR_TX && name == "PA")
    {
        const float v = (float)std::clamp(value, 0.0, 100.0);
        txPaGain_.store(v, std::memory_order_relaxed);
        SoapySDR::logf(SOAPY_SDR_INFO, "TX Drive setGain: name=%s value=%f", name.c_str(), value);
    }
}



// ---------------------------------------------------------------------
// Antenna support stubs (for piHPSDR compatibility)
// ---------------------------------------------------------------------

std::vector<std::string> SBITXDevice::listAntennas(const int, const size_t) const
{
    return { "ANT" };  // single antenna label
}

void SBITXDevice::setAntenna(const int, const size_t, const std::string &)
{
    // Nothing to do — only one antenna
}

std::string SBITXDevice::getAntenna(const int, const size_t) const
{
    return "ANT";
}

void SBITXDevice::setSampleRate(const int, const size_t, const double rate)
{
    if (std::llround(rate) != 48000)
        throw std::runtime_error("SBITX: only 48000 sps supported");
}

double SBITXDevice::getSampleRate(const int, const size_t) const
{
    return 48000.0;
}

void SBITXDevice::setFrequency(const int, const size_t, const std::string &name,
                               const double frequency, const SoapySDR::Kwargs &)
{
    if (name != "RF") return;

    tuneHz_.store((long long)std::llround(frequency));

    // Hardware LO is offset by IF (like your Quisk bridge)
    const long long hw = (long long)std::llround(frequency - ifHz_);

    if (ctrlEnabled_)
    {
        if (!ctrlSetFreqHz(hw))
        {
            SoapySDR::logf(SOAPY_SDR_WARNING, "SBITX ctrlSetFreqHz(%lld) failed", hw);
        }
    }
}

double SBITXDevice::getFrequency(const int, const size_t, const std::string &name) const
{
    if (name != "RF") return 0.0;

    // Prefer asking hardware if ctrl is enabled
    if (ctrlEnabled_)
    {
        long long hw = 0;
        if (ctrlGetFreqHz(hw))
        {
            // hw is LO; report RF = hw + IF
            return (double)hw + ifHz_;
        }
    }
    return (double)tuneHz_.load();
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
    if (format != SOAPY_SDR_CF32) throw std::runtime_error("SBITX: only CF32 supported");
    if (!channels.empty() && channels.at(0) != 0) throw std::runtime_error("SBITX: only channel 0");

    if (direction == SOAPY_SDR_RX)
    {
        if (!openAlsaCapture()) throw std::runtime_error("SBITX: ALSA capture open failed");
        rxUsers_.fetch_add(1);
        return (SoapySDR::Stream*)new SBITXStream{SOAPY_SDR_RX, 0};
    }
    else if (direction == SOAPY_SDR_TX)
    {
        if (!openAlsaPlayback()) throw std::runtime_error("SBITX: ALSA playback open failed");
        txUsers_.fetch_add(1);
        return (SoapySDR::Stream*)new SBITXStream{SOAPY_SDR_TX, 0};
    }

    throw std::runtime_error("SBITX: invalid direction");
}

void SBITXDevice::closeStream(SoapySDR::Stream *stream)
{
    auto *s = reinterpret_cast<SBITXStream*>(stream);
    if (!s) return;

    if (s->direction == SOAPY_SDR_RX)
    {
        int after = rxUsers_.fetch_sub(1) - 1;
        if (after <= 0)
        {
            stopRxThread();
            closeAlsaCapture();
        }
    }
    else if (s->direction == SOAPY_SDR_TX)
    {
        int after = txUsers_.fetch_sub(1) - 1;
        if (after <= 0)
        {
            closeAlsaPlayback();
        }
    }

    delete s;
}

int SBITXDevice::activateStream(SoapySDR::Stream *stream, const int, const long long, const size_t)
{
    auto *s = reinterpret_cast<SBITXStream*>(stream);
    if (s && s->direction == SOAPY_SDR_RX)
        startRxThread();
    return 0;
}

int SBITXDevice::deactivateStream(SoapySDR::Stream *stream, const int, const long long)
{
    auto *s = reinterpret_cast<SBITXStream*>(stream);
    if (s && s->direction == SOAPY_SDR_RX)
        stopRxThread();
    return 0;
}

int SBITXDevice::readStream(SoapySDR::Stream *, void * const *buffs, const size_t numElems,
                            int &flags, long long &timeNs, const long timeoutUs)
{
    flags = 0;
    timeNs = 0;

    auto *out = reinterpret_cast<std::complex<float>*>(buffs[0]);

    const auto t0 = std::chrono::steady_clock::now();
    while (true)
    {
        size_t got = rbRead(out, numElems);
        if (got) return (int)got;

        std::this_thread::sleep_for(std::chrono::microseconds(200));

        auto dt = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - t0).count();
        if (dt > timeoutUs) return SOAPY_SDR_TIMEOUT;
    }
}



bool SBITXDevice::openAlsaCapture()
{
    if (capHandle_) return true;

    int rc = snd_pcm_open(&capHandle_, alsaDev_.c_str(), SND_PCM_STREAM_CAPTURE, 0);
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
        SoapySDR::logf(SOAPY_SDR_ERROR, "snd_pcm_hw_params CAP failed: %s", snd_strerror(rc));
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

bool SBITXDevice::openAlsaPlayback()
{
    if (pbHandle_) return true;

    int rc = snd_pcm_open(&pbHandle_, alsaDev_.c_str(), SND_PCM_STREAM_PLAYBACK, 0);
    if (rc < 0)
    {
        SoapySDR::logf(SOAPY_SDR_ERROR, "snd_pcm_open PB failed: %s", snd_strerror(rc));
        pbHandle_ = nullptr;
        return false;
    }

    snd_pcm_hw_params_t *hw;
    snd_pcm_hw_params_alloca(&hw);
    snd_pcm_hw_params_any(pbHandle_, hw);
    snd_pcm_hw_params_set_access(pbHandle_, hw, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(pbHandle_, hw, SND_PCM_FORMAT_S32_LE);
    snd_pcm_hw_params_set_channels(pbHandle_, hw, 2);

    unsigned int rate = pbFs_;
    snd_pcm_hw_params_set_rate_near(pbHandle_, hw, &rate, nullptr);

    snd_pcm_hw_params_set_period_size_near(pbHandle_, hw, &periodFrames_, nullptr);
    snd_pcm_hw_params_set_buffer_size_near(pbHandle_, hw, &bufferFrames_);

    rc = snd_pcm_hw_params(pbHandle_, hw);
    if (rc < 0)
    {
        SoapySDR::logf(SOAPY_SDR_ERROR, "snd_pcm_hw_params PB failed: %s", snd_strerror(rc));
        snd_pcm_close(pbHandle_);
        pbHandle_ = nullptr;
        return false;
    }

    snd_pcm_prepare(pbHandle_);
    return true;
}

void SBITXDevice::closeAlsaPlayback()
{
    if (!pbHandle_) return;
    snd_pcm_drop(pbHandle_);
    snd_pcm_close(pbHandle_);
    pbHandle_ = nullptr;
}

void SBITXDevice::startRxThread()
{
    if (rxRun_.exchange(true)) return;
    rxThread_ = std::thread(&SBITXDevice::rxThreadMain, this);

#ifdef __linux__
    if (rt_)
    {
        sched_param sp{};
        sp.sched_priority = rtPrio_;
        pthread_setschedparam(rxThread_.native_handle(), SCHED_FIFO, &sp);
    }
#endif
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
    size_t avail = (rbHead_ + rbSize_ - rbTail_) % rbSize_;
    size_t take = std::min(n, avail);
    for (size_t i = 0; i < take; i++)
    {
        out[i] = rb_[rbTail_];
        rbTail_ = (rbTail_ + 1) % rbSize_;
    }
    return take;
}

void SBITXDevice::rxThreadMain()
{
    // Capture 96k stereo S32 from WM8731:
    // Left = real IF (audio), Right = MIC (ignored here)
    //
    // Create complex IQ at 48k:
    //  1) Mix down by e^{-j*ph} at IF
    //  2) 2-tap boxcar lowpass and decimate-by-2 (reduces alias/images)
    //
    std::vector<int32_t> inFrames(periodFrames_ * 2);
    std::vector<std::complex<float>> outIQ(periodFrames_ / 2);

    double ph = rxPhase_;
    const double w = 2.0 * M_PI * (ifHz_ / (double)capFs_);

    while (rxRun_.load())
    {
        // PTT watchdog: if TX was keyed but no TX samples arrive, unkey after a timeout.
        if (txActive_.load(std::memory_order_relaxed))
        {
            const auto nowNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now().time_since_epoch()).count();
            const auto lastNs = lastTxNs_.load(std::memory_order_relaxed);
            // 250 ms without TX samples => assume client left MOX, unkey.
            if (lastNs != 0 && (nowNs - lastNs) > 250000000LL)
            {
                (void)ctrlSetPTT(false);
                txActive_.store(false, std::memory_order_relaxed);
            }
        }

        snd_pcm_sframes_t rd = snd_pcm_readi(capHandle_, inFrames.data(), periodFrames_);
        if (rd < 0)
        {
            rd = snd_pcm_recover(capHandle_, (int)rd, 1);
            if (rd < 0)
            {
                SoapySDR::logf(SOAPY_SDR_WARNING, "RX snd_pcm_readi recover failed: %s", snd_strerror((int)rd));
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
                continue;
            }
            continue;
        }

        const size_t frames = (size_t)rd;

        size_t o = 0;
        for (size_t n = 0; n + 1 < frames; n += 2)
        {
            // sample n
            float x0 = (float)inFrames[n*2 + 0] / 2147483647.0f;
            float c0 = (float)std::cos(ph);
            float s0 = (float)std::sin(ph);
            std::complex<float> z0(x0 * c0, -x0 * s0); // x * e^{-j ph}
            ph += w;
            if (ph > M_PI) ph -= 2.0 * M_PI;

            // sample n+1
            float x1 = (float)inFrames[(n+1)*2 + 0] / 2147483647.0f;
            float c1 = (float)std::cos(ph);
            float s1 = (float)std::sin(ph);
            std::complex<float> z1(x1 * c1, -x1 * s1);
            ph += w;
            if (ph > M_PI) ph -= 2.0 * M_PI;

            // 2-tap LPF + decimate
            std::complex<float> y = (z0 + z1) * 0.5f;

            float I = y.real();
            float Q = y.imag();

            if (iqInv_) Q = -Q;
            if (iqSwap_) std::swap(I, Q);

            outIQ[o++] = std::complex<float>(I, Q);
        }

        if (o) rbWrite(outIQ.data(), o);
    }

    rxPhase_ = ph;
}

// ------------------- ctrl TCP -------------------

bool SBITXDevice::ctrlSendLine(const std::string &line) const
{
#ifndef __linux__
    (void)line;
    return false;
#else
    if (!ctrlEnabled_) return false;

    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    addrinfo *res = nullptr;
    const std::string port = std::to_string(ctrlPort_);
    if (getaddrinfo(ctrlHost_.c_str(), port.c_str(), &hints, &res) != 0) return false;

    int fd = -1;
    for (addrinfo *p = res; p; p = p->ai_next)
    {
        fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (fd < 0) continue;
        if (connect(fd, p->ai_addr, p->ai_addrlen) == 0) break;
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    if (fd < 0) return false;

    std::string msg = line;
    if (msg.empty() || msg.back() != '\n') msg.push_back('\n');
    ssize_t w = ::write(fd, msg.data(), msg.size());
    close(fd);
    return w == (ssize_t)msg.size();
#endif
}

bool SBITXDevice::ctrlQueryLine(const std::string &line, std::string &reply) const
{
#ifndef __linux__
    (void)line; (void)reply;
    return false;
#else
    if (!ctrlEnabled_) return false;

    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    addrinfo *res = nullptr;
    const std::string port = std::to_string(ctrlPort_);
    if (getaddrinfo(ctrlHost_.c_str(), port.c_str(), &hints, &res) != 0) return false;

    int fd = -1;
    for (addrinfo *p = res; p; p = p->ai_next)
    {
        fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (fd < 0) continue;
        if (connect(fd, p->ai_addr, p->ai_addrlen) == 0) break;
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    if (fd < 0) return false;

    std::string msg = line;
    if (msg.empty() || msg.back() != '\n') msg.push_back('\n');
    if (::write(fd, msg.data(), msg.size()) != (ssize_t)msg.size())
    {
        close(fd);
        return false;
    }

    char buf[128];
    ssize_t r = ::read(fd, buf, sizeof(buf)-1);
    close(fd);
    if (r <= 0) return false;
    buf[r] = 0;

    reply = std::string(buf);
    // trim
    while (!reply.empty() && (reply.back() == '\n' || reply.back() == '\r' || reply.back() == ' '))
        reply.pop_back();
    return !reply.empty();
#endif
}

bool SBITXDevice::ctrlSetFreqHz(long long hz) const
{
    std::ostringstream ss;
    ss << "F " << hz;
    return ctrlSendLine(ss.str());
}

bool SBITXDevice::ctrlGetFreqHz(long long &hz) const
{
    std::string rep;
    if (!ctrlQueryLine("f", rep)) return false;

    // rep can be "14056000" or "OK 14056000" depending on implementation
    long long val = 0;
    if (rep.rfind("OK", 0) == 0)
    {
        std::istringstream is(rep.substr(2));
        is >> val;
    }
    else
    {
        std::istringstream is(rep);
        is >> val;
    }
    if (val <= 0) return false;
    hz = val;
    return true;
}

bool SBITXDevice::ctrlSetPTT(bool on) const
{
    std::ostringstream ss;
    ss << "T " << (on ? 1 : 0);
    return ctrlSendLine(ss.str());
}


size_t SBITXDevice::getNumChannels(const int /*direction*/) const
{
    // One logical RX and one logical TX channel.
    return 1;
}

bool SBITXDevice::getFullDuplex(const int /*direction*/, const size_t /*channel*/) const
{
    // Not full-duplex: helps pihpsdr avoid assuming TX is always active.
    return false;
}

int SBITXDevice::writeStream(
    SoapySDR::Stream *,
    const void * const *buffs,
    const size_t numElems,
    int &flags,
    const long long,
    const long)
{
    flags = 0;

    if (!pbHandle_)
        return SOAPY_SDR_STREAM_ERROR;

    const auto *in =
        reinterpret_cast<const std::complex<float> *>(buffs[0]);

    // Key PTT on first TX samples
    if (!txActive_.load(std::memory_order_relaxed))
    {
        (void)ctrlSetPTT(true);
        txActive_.store(true, std::memory_order_relaxed);
    }

    const auto nowNs =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count();

    lastTxNs_.store(nowNs, std::memory_order_relaxed);

    // 48k IQ → 96k real IF (RIGHT channel)
    std::vector<int32_t> out(numElems * 2 * 2);
    
    const double w = 2.0 * M_PI * (ifHz_ / pbFs_);
    double ph = txPhase_;
    //txGainDb_ = -10.0;
    size_t o = 0;
    for (size_t n = 0; n < numElems; n++)
{
    float I = in[n].real();
    float Q = in[n].imag();

    if (iqSwap_)
        std::swap(I, Q);

    for (int k = 0; k < 2; k++)   // two output samples
    {
        const float gain = txPaGain_.load(std::memory_order_relaxed) * (1.0f / 100.0f);
        float y = I * std::cos(ph) - Q * std::sin(ph);
        y *= gain;
        ph += w;
        if (ph > 2.0 * M_PI)
            ph -= 2.0 * M_PI;

        int32_t s = float_to_s32(y);

        out[o++] = 0;  // L unused
        out[o++] = s;  // R = TX IF
    }
}
    txPhase_ = ph;

    const snd_pcm_uframes_t outFrames =
    (snd_pcm_uframes_t)(numElems * 2);

snd_pcm_uframes_t written = 0;

while (written < outFrames)
{
    snd_pcm_sframes_t rc =
        snd_pcm_writei(
            pbHandle_,
            out.data() + (written * 2),   // stereo = 2 ints per frame
            outFrames - written);

    if (rc == -EAGAIN)
        continue;

    if (rc < 0)
    {
        rc = snd_pcm_recover(pbHandle_, (int)rc, 1);
        if (rc < 0)
            return SOAPY_SDR_STREAM_ERROR;
        continue;
    }

    written += (snd_pcm_uframes_t)rc;
}

return (int)numElems;
}
