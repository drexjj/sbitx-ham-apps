#!/bin/bash
set -e

# ============================================================
# piHPSDR + SoapySDR Install Script
# Raspberry Pi 4 / 64-bit (Bookworm)
# dl1ycf/pihpsdr
# ============================================================

SRC_DIR="$HOME/github"
WDSP_REPO="https://github.com/g0orx/wdsp.git"
PIHPSDR_REPO="https://github.com/dl1ycf/pihpsdr.git"
JOBS=$(nproc)

echo "============================================"
echo " piHPSDR + SoapySDR Installer"
echo " Raspberry Pi 4 (64-bit)"
echo "============================================"

# ------------------------------------------------------------
# 1. Dependencies
# ------------------------------------------------------------
echo "[1/8] Installing dependencies..."

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
# 2. Source directory
# ------------------------------------------------------------
echo "[2/8] Preparing source directory..."
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# ------------------------------------------------------------
# 3. Clone repositories
# ------------------------------------------------------------
echo "[3/8] Cloning repositories..."

[ ! -d wdsp ] && git clone "$WDSP_REPO"
[ ! -d pihpsdr ] && git clone "$PIHPSDR_REPO"

# ------------------------------------------------------------
# 4. Build WDSP
# ------------------------------------------------------------
echo "[4/8] Building WDSP..."
cd "$SRC_DIR/wdsp"
make clean
make -j"$JOBS"
sudo make install
sudo ldconfig

# ------------------------------------------------------------
# 5. Build piHPSDR (Soapy enabled)
# ------------------------------------------------------------
echo "[5/8] Building piHPSDR..."
cd "$SRC_DIR/pihpsdr"

# Ensure Soapy is enabled
if ! grep -q "SOAPYSDR=1" Makefile; then
    sed -i 's/^#*SOAPYSDR=.*/SOAPYSDR=1/' Makefile
fi

make clean
make -j"$JOBS"

# ------------------------------------------------------------
# 6. Install binary
# ------------------------------------------------------------
echo "[6/8] Installing piHPSDR..."

sudo mkdir -p /opt/pihpsdr
sudo cp pihpsdr /opt/pihpsdr/
sudo chmod +x /opt/pihpsdr/pihpsdr

# Symlink for CLI use
sudo ln -sf /opt/pihpsdr/pihpsdr /usr/local/bin/pihpsdr

# ------------------------------------------------------------
# 7. Desktop Entry
# ------------------------------------------------------------
echo "[7/8] Creating desktop entry..."

sudo tee /usr/share/applications/pihpsdr.desktop > /dev/null <<EOF
[Desktop Entry]
Name=piHPSDR
Comment=HPSDR SDR Client
Exec=/usr/local/bin/pihpsdr
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=HamRadio;AudioVideo;
EOF

sudo chmod 644 /usr/share/applications/pihpsdr.desktop

# ------------------------------------------------------------
# 8. Final notes
# ------------------------------------------------------------
echo "============================================"
echo " Installation Complete"
echo "============================================"
echo
echo "Launch from menu or run:"
echo "  pihpsdr"
echo
echo "To verify SoapySDR:"
echo "  SoapySDRUtil --find"
echo
echo "GPIO users:"
echo "Add to /boot/config.txt if needed:"
echo "  gpio=4-13,16-27=ip,pu"
echo
echo "First run will generate FFTW wisdom."
echo "============================================"
