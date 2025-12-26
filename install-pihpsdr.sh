#!/bin/bash
set -e

# -----------------------------
# Configuration
# -----------------------------
SRC_DIR="$HOME/github"
WDSP_REPO="https://github.com/g0orx/wdsp.git"
PIHPSDR_REPO="https://github.com/g0orx/pihpsdr.git"
JOBS=$(nproc)

echo "========================================"
echo " piHPSDR Install Script"
echo "========================================"

# -----------------------------
# Install prerequisites
# -----------------------------
echo "[1/9] Installing prerequisites..."
sudo apt update
sudo apt install -y \
    git build-essential \
    libfftw3-dev \
    libgtk-3-dev \
    libpulse-dev \
    libpulse-mainloop-glib0 \
    libasound2-dev \
    libusb-1.0-0-dev \
    libgpiod-dev \
    libi2c-dev

# -----------------------------
# Create source directory
# -----------------------------
echo "[2/9] Creating source directory..."
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# -----------------------------
# Clone repositories
# -----------------------------
echo "[3/9] Cloning repositories..."

if [ ! -d "wdsp" ]; then
    git clone "$WDSP_REPO"
else
    echo "WDSP already exists, skipping clone."
fi

if [ ! -d "pihpsdr" ]; then
    git clone "$PIHPSDR_REPO"
else
    echo "piHPSDR already exists, skipping clone."
fi

# -----------------------------
# Build and install WDSP
# -----------------------------
echo "[4/9] Building WDSP..."
cd "$SRC_DIR/wdsp"
make clean
make -j"$JOBS"
sudo make install

# Copy libwdsp.so into piHPSDR release directory
echo "Copying libwdsp.so to piHPSDR release directory..."
cp -f libwdsp.so "$SRC_DIR/pihpsdr/release/pihpsdr"

# -----------------------------
# Build piHPSDR (release)
# -----------------------------
echo "[5/9] Building piHPSDR..."
cd "$SRC_DIR/pihpsdr"
make clean
make -j"$JOBS"
make release

# -----------------------------
# Install piHPSDR
# -----------------------------
echo "[6/9] Installing piHPSDR..."
cd "$HOME"
tar xvf "$SRC_DIR/pihpsdr/release/pihpsdr.tar"
cd pihpsdr
sh ./install.sh

# -----------------------------
# GPIO configuration note
# -----------------------------
echo "----------------------------------------"
echo "IMPORTANT GPIO CONFIGURATION"
echo "----------------------------------------"
echo "If using Controller 1 or Controller 2,"
echo "add the following to /boot/config.txt:"
echo
echo "[all]"
echo "# setup GPIO for piHPSDR Controller 2"
echo "gpio=4-13,16-27=ip,pu"
echo
echo "Then reboot the Raspberry Pi."
echo "----------------------------------------"

# -----------------------------
# FFTW Wisdom notice
# -----------------------------
echo "NOTE:"
echo "The first time piHPSDR is run, FFTW3 wisdom"
echo "will be generated. This may take a few minutes."

# -----------------------------
# Optional: SoapySDR support
# -----------------------------
echo "[7/9] Installing SoapySDR support (optional)..."
sudo apt install -y libsoapysdr-dev

echo "[8/9] Enabling SoapySDR in Makefile..."
cd "$SRC_DIR/pihpsdr"

if grep -q "^#SOAPYSDR_INCLUDE=SOAPYSDR" Makefile; then
    sed -i 's/^#SOAPYSDR_INCLUDE=SOAPYSDR/SOAPYSDR_INCLUDE=SOAPYSDR/' Makefile
    echo "SoapySDR enabled in Makefile."
else
    echo "SoapySDR already enabled or line not found."
fi

# -----------------------------
# Rebuild and install piHPSDR with SoapySDR
# -----------------------------
echo "[9/9] Rebuilding piHPSDR with SoapySDR..."
make clean
make -j"$JOBS"
sudo make install

echo "========================================"
echo " piHPSDR installation completed!"
echo "========================================"
echo "You can start piHPSDR using the desktop icon."
