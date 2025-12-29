#include <SoapySDR/Registry.hpp>
#include "SBITXDevice.hpp"

static SoapySDR::KwargsList findSBITX(const SoapySDR::Kwargs &)
{
    SoapySDR::KwargsList results;
    SoapySDR::Kwargs dev;
    dev["driver"] = "sbitx";
    dev["label"] = "sBitx (ALSA IQ bridge)";
    results.push_back(dev);
    return results;
}

static SoapySDR::Device *makeSBITX(const SoapySDR::Kwargs &args)
{
    return new SBITXDevice(args);
}

static SoapySDR::Registry registerSBITX("sbitx", &findSBITX, &makeSBITX, SOAPY_SDR_ABI_VERSION);
