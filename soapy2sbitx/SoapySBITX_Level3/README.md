# SoapySBITX (Option A – Level 2)

This is a **SoapySDR** driver that makes an **sBitx** appear as a Soapy device by reading the **WM8731** audio codec via ALSA and producing **complex IQ**.

## What Level 2 does

- Opens **ALSA capture** on the WM8731 (default `hw:0,0`) at **96 kHz, stereo, S32_LE**
- Uses **Left channel as IF audio** (real samples)
- Mixes down by `--if` (default **24000 Hz**) to baseband and **decimates 96k → 48k**
- Exposes a Soapy RX stream at **48 kS/s**, complex float (CF32)

### Channel mapping (important)

This matches your working bridge mapping:

- **WM8731 capture (`hw:0,0`)**
  - Left  = IF audio
  - Right = MIC (ignored in Level 2 RX-only driver)

So you should **NOT** hear your mic inside the IQ stream anymore.

## Install prerequisites

You need SoapySDR runtime + dev headers:

```bash
sudo apt update
sudo apt install -y soapysdr-tools libsoapysdr-dev
```

## Build and install

```bash
mkdir -p build
cd build
cmake ..
make -j2
sudo make install
sudo ldconfig
```

## Quick tests

### 1) Confirm the module loads
```bash
SoapySDRUtil --info
```

You should see `Available factories... sbitx` and a module line like `SoapySBITX.so`.

### 2) Probe the device
```bash
SoapySDRUtil --probe="driver=sbitx,alsa=hw:0,0,if=24000"
```

### 3) Run CubicSDR as a sanity check (RX)
In CubicSDR:
- Device: **sbitx (ALSA IQ bridge)**
- Sample rate: **48 kHz**
- Start

If you want to see driver logs:
```bash
SOAPY_SDR_LOG_LEVEL=DEBUG CubicSDR
```

## Do I have to start sbitx_ctrl?

**For Level 2 RX-only IQ streaming: No.**

Level 2 is only doing the **audio/IQ path**. Frequency/PTT control integration will be added in later levels.

## Driver arguments

- `driver=sbitx` (required)
- `alsa=hw:0,0` ALSA capture device (default `hw:0,0`)
- `if=24000` IF in Hz (default 24000)
- `iq_swap=0|1` swap I/Q (default 0)
- `period=NNN` ALSA period frames (default 1000)
- `buffer=NNN` ALSA buffer frames (default 4000)
- `rt=0|1` enable RT scheduling (default 0)
- `rt_prio=NNN` RT priority (default 70)

Example:
```bash
SoapySDRUtil --probe="driver=sbitx,alsa=hw:0,0,if=24000,period=1000,buffer=4000,rt=1,rt_prio=70"
```
