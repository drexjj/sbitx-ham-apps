#!/bin/bash
set -e

# ============================================================
# piHPSDR + SoapySDR Install Script
# Raspberry Pi 4 (64-bit)
# Repo: https://github.com/dl1ycf/pihpsdr
# ============================================================

SRC_DIR="$HOME/github"
WDSP_REPO="https://github.com/g0orx/wdsp.git"
PIHPSDR_REPO="https://github.com/dl1ycf/pihpsdr.git"
JOBS=$(nproc)

echo "============================================"
echo " piHPSDR + SoapySDR Install (RPi 4 / 64-bit)"
echo "============================================"

# ------------------------------------------------------------
# 1. Install dependencies
# ------------------------------------------------------------
echo "[1/9] Installing dependencies..."

sudo apt update
sudo apt install -y \
    git build-essential cmake pkg-config \
    libfftw3-dev \
    libgtk-3-dev \
    libpulse-dev libpulse-mainloop-glib0 \
    libasound2-dev \
    libusb-1.0-0-dev \
    libi2c-dev \
    libgpiod-dev \
    libsoapysdr-dev \
    soapysdr-tools

# ------------------------------------------------------------
# 2. Prepare source directory
# ------------------------------------------------------------
echo "[2/9] Preparing source directory..."
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# ------------------------------------------------------------
# 3. Clone repositories
# ------------------------------------------------------------
echo "[3/9] Cloning repositories..."

if [ ! -d "wdsp" ]; then
    git clone "$WDSP_REPO"
fi

if [ ! -d "pihpsdr" ]; then
    git clone "$PIHPSDR_REPO"
fi

# ------------------------------------------------------------
# 4. Build WDSP
# ------------------------------------------------------------
echo "[4/9] Building WDSP..."
cd "$SRC_DIR/wdsp"
make clean
make -j"$JOBS"
sudo make install
sudo ldconfig

# ------------------------------------------------------------
# 5. Build piHPSDR (with Soapy)
# ------------------------------------------------------------
echo "[5/9] Building piHPSDR..."
cd "$SRC_DIR/pihpsdr"

# Enable SoapySDR support explicitly
if ! grep -q "SOAPYSDR=1" Makefile; then
    echo "Enabling SoapySDR support..."
    sed -i 's/^#*SOAPYSDR=.*/SOAPYSDR=1/' Makefile
fi

make clean
make -j"$JOBS"

# ------------------------------------------------------------
# 6. Install piHPSDR
# ------------------------------------------------------------
echo "[6/9] Installing piHPSDR..."
sudo make install
sudo ldconfig

# ------------------------------------------------------------
# 7. GPIO Info
# ------------------------------------------------------------
echo "--------------------------------------------------"
echo " GPIO CONFIGURATION (if using HPSDR controller)"
echo "--------------------------------------------------"
echo "Add to /boot/config.txt:"
echo
echo "[all]"
echo "gpio=4-13,16-27=ip,pu"
echo
echo "Then reboot."
echo "--------------------------------------------------"

# ------------------------------------------------------------
# 8. Verify SoapySDR
# ------------------------------------------------------------
echo "[8/9] Verifying SoapySDR..."
SoapySDRUtil --info || true

# ------------------------------------------------------------
# 9. Done
# ------------------------------------------------------------
echo "============================================"
echo " Installation complete!"
echo "============================================"
echo
echo "Run with:"
echo "  pihpsdr"
echo
echo "Soapy devices can be tested with:"
echo "  SoapySDRUtil --find"
echo
echo "First launch may take time while FFTW wisdom is generated."
