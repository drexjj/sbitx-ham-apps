#pragma once

#include <SoapySDR/Device.hpp>
#include <SoapySDR/Types.hpp>

#include <alsa/asoundlib.h>

#include <atomic>
#include <chrono>
#include <complex>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class SBITXDevice : public SoapySDR::Device
{
public:
    SBITXDevice(const SoapySDR::Kwargs &args);
    ~SBITXDevice() override;

    // Identification / info
    SoapySDR::Kwargs getHardwareInfo() const override;

    
    size_t getNumChannels(const int direction) const override;
    bool getFullDuplex(const int direction, const size_t channel) const override;
// Rates / frequency
    std::vector<double> listSampleRates(const int direction, const size_t channel) const override;
    void setSampleRate(const int direction, const size_t channel, const double rate) override;
    double getSampleRate(const int direction, const size_t channel) const override;

    void setFrequency(const int direction, const size_t channel,
                      const std::string &name, const double frequency,
                      const SoapySDR::Kwargs &args) override;
    double getFrequency(const int direction, const size_t channel,
                        const std::string &name) const override;
    std::vector<std::string> listGains(
    const int direction,
    const size_t channel) const override;

    SoapySDR::Range getGainRange(
    const int direction,
    const size_t channel,
    const std::string &name) const override;

    double getGain(
    const int direction,
    const size_t channel,
    const std::string &name) const override;

    void setGain(
    const int direction,
    const size_t channel,
    const std::string &name,
    const double value) override;
    std::vector<std::string> listFrequencies(const int direction, const size_t channel) const override;
    SoapySDR::RangeList getFrequencyRange(const int direction, const size_t channel, const std::string &name) const override;

    // Streams
    std::vector<std::string> getStreamFormats(const int direction, const size_t channel) const override;
    std::string getNativeStreamFormat(const int direction, const size_t channel, double &fullScale) const override;

    SoapySDR::Stream *setupStream(const int direction, const std::string &format,
                                  const std::vector<size_t> &channels,
                                  const SoapySDR::Kwargs &args) override;

    void closeStream(SoapySDR::Stream *stream) override;
    // Antenna
    std::vector<std::string> listAntennas(const int, const size_t) const override;
    void setAntenna(const int, const size_t, const std::string &) override;
    std::string getAntenna(const int, const size_t) const override;

    int activateStream(SoapySDR::Stream *stream, const int flags,
                       const long long timeNs, const size_t numElems) override;

    int deactivateStream(SoapySDR::Stream *stream, const int flags,
                         const long long timeNs) override;

    int readStream(SoapySDR::Stream *stream, void * const *buffs, const size_t numElems,
                   int &flags, long long &timeNs, const long timeoutUs) override;

    int writeStream(SoapySDR::Stream *stream, const void * const *buffs, const size_t numElems,
                    int &flags, const long long timeNs, const long timeoutUs) override;

private:
    // Stream tag so closeStream knows what it is
    struct SBITXStream
    {
        int direction; // SOAPY_SDR_RX or SOAPY_SDR_TX
        size_t channel;
    };
    
    //std::atomic<float> txPaGain_{1.0f}; //linear pa drive
    //double txGainDb_ = 0.0; //tx if gain
    // ALSA
    bool openAlsaCapture();
    void closeAlsaCapture();
    bool openAlsaPlayback();
    void closeAlsaPlayback();

    // RX thread + ringbuffer
    void startRxThread();
    void stopRxThread();
    void rxThreadMain();

    void rbWrite(const std::complex<float> *in, size_t n);
    size_t rbRead(std::complex<float> *out, size_t n);

    // Control (TCP to sbitx_ctrl)
    bool ctrlSendLine(const std::string &line) const;
    bool ctrlQueryLine(const std::string &line, std::string &reply) const;
    bool ctrlSetFreqHz(long long hz) const;
    bool ctrlGetFreqHz(long long &hz) const;
    bool ctrlSetPTT(bool on) const;

private:
    // Args / config
    std::string alsaDev_ = "hw:0,0";

    unsigned int fs_ = 48000;
    unsigned int capFs_ = 96000;
    unsigned int pbFs_  = 96000;

    double ifHz_ = 24000.0;
    bool iqSwap_ = false;
    bool iqInv_  = false; // invert Q if needed (fix spectrum mirror)

    snd_pcm_uframes_t periodFrames_ = 1000;
    snd_pcm_uframes_t bufferFrames_ = 4000;

    bool rt_ = false;
    int rtPrio_ = 70;

    // ctrl="host:port"  (default 127.0.0.1:9999)
    std::string ctrlHost_ = "127.0.0.1";
    int ctrlPort_ = 9999;
    bool ctrlEnabled_ = true;

    // State
    mutable std::atomic<long long> tuneHz_{0};

    // ALSA handles
    snd_pcm_t *capHandle_ = nullptr;
    snd_pcm_t *pbHandle_  = nullptr;

    std::atomic<bool> txActive_{false};
    std::atomic<long long> lastTxNs_{0};
    // RX thread control
    std::atomic<bool> rxRun_{false};
    std::thread rxThread_;

    // Ring buffer for IQ
    std::vector<std::complex<float>> rb_;
    size_t rbSize_ = 0;
    size_t rbHead_ = 0;
    size_t rbTail_ = 0;
    std::mutex rbMutex_;

    // Stream users (THIS fixes your rxUsers_/txUsers_ errors)
    std::atomic<int> rxUsers_{0};
    std::atomic<int> txUsers_{0};

    // TX buffer reuse (THIS fixes txFrames_ errors)
    std::vector<int32_t> txFrames_;
    double txPhase_ = 0.0;
    double rxPhase_ = 0.0;
};
