#pragma once
#include <SoapySDR/Device.hpp>
#include <alsa/asoundlib.h>
#include <atomic>
#include <complex>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <climits>

class SBITXDevice : public SoapySDR::Device
{
public:
    explicit SBITXDevice(const SoapySDR::Kwargs &args);
    ~SBITXDevice() override;

    std::string getDriverKey() const override { return "sbitx"; }
    std::string getHardwareKey() const override { return "sbitx"; }
    SoapySDR::Kwargs getHardwareInfo() const override;

    size_t getNumChannels(const int /*direction*/) const override { return 1; }

    std::vector<double> listSampleRates(const int /*direction*/, const size_t /*channel*/) const override;
    void setSampleRate(const int direction, const size_t channel, const double rate) override;
    double getSampleRate(const int /*direction*/, const size_t /*channel*/) const override;

    void setFrequency(const int direction, const size_t channel, const std::string &name,
                      const double frequency, const SoapySDR::Kwargs &args) override;
    double getFrequency(const int /*direction*/, const size_t /*channel*/, const std::string &name) const override;

    std::vector<std::string> getStreamFormats(const int /*direction*/, const size_t /*channel*/) const override;
    std::string getNativeStreamFormat(const int /*direction*/, const size_t /*channel*/, double &fullScale) const override;

    SoapySDR::Stream *setupStream(const int direction, const std::string &format,
                                 const std::vector<size_t> &channels = std::vector<size_t>(),
                                 const SoapySDR::Kwargs &args = SoapySDR::Kwargs()) override;
    void closeStream(SoapySDR::Stream *stream) override;

    int activateStream(SoapySDR::Stream *stream, const int flags = 0,
                       const long long timeNs = 0, const size_t numElems = 0) override;
    int deactivateStream(SoapySDR::Stream *stream, const int flags = 0,
                         const long long timeNs = 0) override;

    int readStream(SoapySDR::Stream *stream, void * const *buffs, const size_t numElems,
                   int &flags, long long &timeNs, const long timeoutUs = 100000) override;

private:
    struct RxStream { int placeholder; };

    void startRxThread();
    void stopRxThread();
    void rxThreadMain();

    bool openAlsaCapture();
    void closeAlsaCapture();

    void rbWrite(const std::complex<float>* in, size_t n);
    size_t rbRead(std::complex<float>* out, size_t n);

    // --- sbitx_ctrl TCP control (127.0.0.1:9999 by default) ---
    bool ctrlSetHwFreqHz(long long hz) const;
    bool ctrlGetHwFreqHz(long long &hz) const;

    bool tcpSendRecvLine(const std::string &lineToSend, std::string &replyLine) const;

    std::string ctrlHost_;
    int ctrlPort_{9999};

    std::string alsaCapDev_;
    unsigned int fs_;      // Soapy stream sample rate (IQ)
    unsigned int capFs_;   // ALSA capture sample rate (WM8731)
    double ifHz_;
    bool iqSwap_;
    bool rt_;
    int rtPrio_;
    mutable double tuneHz_{0.0};  // RF frequency exposed to apps (cached)

    snd_pcm_t *capHandle_{nullptr};
    snd_pcm_uframes_t periodFrames_{1000};
    snd_pcm_uframes_t bufferFrames_{4000};

    std::thread rxThread_;
    std::atomic<bool> rxRun_{false};

    std::mutex rbMutex_;
    std::vector<std::complex<float>> rb_;
    size_t rbHead_{0};
    size_t rbTail_{0};
    size_t rbSize_{0};

    double phase_{0.0};
};
