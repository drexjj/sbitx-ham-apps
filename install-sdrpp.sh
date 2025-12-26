#!/usr/bin/env bash
# 2025 version - for Raspberry Pi 4 64-bit (Bookworm)
# Builds SDR++ with RTL-SDR + popular modules + SoapySDR support
# Run as regular user (uses sudo when needed)

set -e

echo "=== SDR++ installer for Raspberry Pi 4 (64-bit) ==="
echo "This will take 20-60 minutes depending on your SD card/USB speed"
echo "Make sure you are running 64-bit Raspberry Pi OS (Bookworm)!"
echo

echo "[1/5] Updating system & installing build dependencies..."
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
    build-essential cmake git \
    libfftw3-dev libglfw3-dev libglew-dev \
    libvolk2-dev libzstd-dev libzstd1 \
    libsoapysdr-dev \
    libairspy-dev libairspyhf-dev \
    librtlsdr-dev \
    libhackrf-dev \
    librtaudio-dev \
    libusb-1.0-0-dev \
    libiio-dev libad9361-dev \
    portaudio19-dev \
    libcodec2-dev

echo
echo "[2/5] Cloning latest SDR++ source..."
cd ~
if [ -d "SDRPlusPlus" ]; then
    echo "SDRPlusPlus directory already exists → pulling latest changes"
    cd SDRPlusPlus
    git pull
    cd ..
else
    git clone https://github.com/AlexandreRouma/SDRPlusPlus.git
fi

echo
echo "[3/5] Preparing build directory..."
cd SDRPlusPlus
rm -rf build 2>/dev/null || true
mkdir build && cd build

echo
echo "[4/5] Running CMake with popular modules enabled..."
cmake .. \
    -DOPT_BUILD_RTL_SDR_SOURCE=ON \
    -DOPT_BUILD_AIRSPY_SOURCE=ON \
    -DOPT_BUILD_AIRSPYHF_SOURCE=ON \
    -DOPT_BUILD_HACKRF_SOURCE=ON \
    -DOPT_BUILD_SOAPY_SOURCE=ON \
    -DOPT_BUILD_NEW_PORTAUDIO_SINK=ON \
    -DCMAKE_BUILD_TYPE=Release

echo
echo "[5/5] Compiling & installing... (this will take the longest)"
make -j4
sudo make install
sudo ldconfig

echo
echo "=============================================================="
echo "                  Installation finished!"
echo "=============================================================="
echo
echo "Run SDR++ with:                sdrpp"
echo "If it doesn't start → try:     sdrpp --help"
echo
echo "Tips:"
echo "  • First start may take a few seconds (shader compilation)"
echo "  • For best performance use at least 4GB Pi 4 model"
echo "  • If you get OpenGL errors → make sure you use Wayland or have proper GPU drivers"
echo "  • Want more modules? Edit cmake options (see https://github.com/AlexandreRouma/SDRPlusPlus#module-list)"
