#!/bin/bash
# Exit on any error
set -e

echo "======================================"
echo "  sBitx CubicSDR installer"
echo "  Select which drivers to install"
echo "======================================"
echo

# Default choices (change to "y" if you want them selected by default)
INSTALL_SDRPLAY="n"
INSTALL_RTLSDR="n"
INSTALL_SBITX_SOAPY="n"

# You can also pass arguments: ./install.sh sdrplay rtl sbitx
for arg in "$@"; do
    case "$arg" in
        sdrplay) INSTALL_SDRPLAY="y" ;;
        rtl|rtlsdr) INSTALL_RTLSDR="y" ;;
        sbitx|sbitxsoapy) INSTALL_SBITX_SOAPY="y" ;;
    esac
done

if [[ "$INSTALL_SDRPLAY$INSTALL_RTLSDR$INSTALL_SBITX_SOAPY" == "nnn" ]]; then
    echo "Which drivers do you want to install? (y/N)"
    echo
    read -p "SDRplay (API + Soapy module)     [y/N]: " -n 1 -r SDRPLAY_ANS
    echo
    read -p "RTL-SDR (SoapyRTLSDR module)     [y/N]: " -n 1 -r RTLSDR_ANS
    echo
    read -p "sbitx experimental Soapy driver  [y/N]: " -n 1 -r SBITX_ANS
    echo

    [[ $SDRPLAY_ANS =~ ^[Yy]$ ]] && INSTALL_SDRPLAY="y"
    [[ $RTLSDR_ANS  =~ ^[Yy]$ ]] && INSTALL_RTLSDR="y"
    [[ $SBITX_ANS   =~ ^[Yy]$ ]] && INSTALL_SBITX_SOAPY="y"
fi

echo
echo "Summary of choices:"
echo "  SDRplay .................... $( [[ $INSTALL_SDRPLAY == "y" ]] && echo "YES" || echo "no" )"
echo "  RTL-SDR Soapy module ....... $( [[ $INSTALL_RTLSDR == "y" ]] && echo "YES" || echo "no" )"
echo "  sbitx Soapy driver ......... $( [[ $INSTALL_SBITX_SOAPY == "y" ]] && echo "YES" || echo "no" )"
echo
read -p "Continue? (Press Enter to proceed, Ctrl+C to cancel) "
echo

echo "Updating package lists..."
sudo apt update

echo "Installing common dependencies..."
sudo apt install -y \
    libwxgtk3.2-dev \
    libpulse-dev \
    libasound2-dev \
    libportaudio2 portaudio19-dev \
    libliquid-dev \
    libsoapysdr-dev soapysdr-tools \
    libgtk-3-dev freeglut3-dev \
    cmake git

# ── SoapySDR core ────────────────────────────────────────────────────────────
echo "Installing / updating SoapySDR..."
cd ~
rm -rf SoapySDR
git clone https://github.com/pothosware/SoapySDR.git
cd SoapySDR
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4
sudo make install
sudo ldconfig

# ── SDRplay ──────────────────────────────────────────────────────────────────
if [[ $INSTALL_SDRPLAY == "y" ]]; then
    echo "Installing SDRplay API..."
    cd ~
    wget -nc https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.2.run
    chmod +x SDRplay_RSP_API-Linux-3.15.2.run
    
    echo " → Launching SDRplay installer"
    echo "   Press Enter, then q, then y, then y when prompted"
    echo "   (or follow on-screen instructions)"
    sleep 2
    sudo ./SDRplay_RSP_API-Linux-3.15.2.run

    echo "Installing SoapySDRPlay module..."
    cd ~
    rm -rf SoapySDRPlay
    git clone https://github.com/pothosware/SoapySDRPlay.git
    cd SoapySDRPlay
    mkdir -p build && cd build
    cmake ..
    make -j4
    sudo make install
    sudo ldconfig
fi

# ── RTL-SDR ──────────────────────────────────────────────────────────────────
if [[ $INSTALL_RTLSDR == "y" ]]; then
    echo "Installing SoapyRTLSDR module..."
    cd ~
    rm -rf SoapyRTLSDR
    git clone https://github.com/pothosware/SoapyRTLSDR.git
    cd SoapyRTLSDR
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j4
    sudo make install
    sudo ldconfig
fi

# ── sbitx Soapy driver ───────────────────────────────────────────────────────
if [[ $INSTALL_SBITX_SOAPY == "y" ]]; then
    echo "Installing experimental sbitx Soapy driver (rx only)..."
    cd ~/sbitx-ham-apps/soapy2sbitx || {
        echo "Error: ~/sbitx-ham-apps/soapy2sbitx directory not found!"
        echo "       Is sbitx-ham-apps repository cloned?"
        exit 1
    }
    mkdir -p build
    cd build
    cmake ..
    make -j4
    sudo make install
    sudo ldconfig
fi

# ── CubicSDR ─────────────────────────────────────────────────────────────────
echo "Installing / updating CubicSDR (with audio support)..."
cd ~
rm -rf CubicSDR
git clone https://github.com/cjcliffe/CubicSDR.git
cd CubicSDR
mkdir -p build && cd build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_HAMLIB=ON \
    -DUSE_AUDIO=ON \
    -DUSE_PORTAUDIO=ON
make -j4
sudo make install

# ── Icon fix ─────────────────────────────────────────────────────────────────
if [[ -d ~/sbitx-ham-apps/cubicsdr ]]; then
    echo "Applying CubicSDR menu icon fix..."
    cd ~/sbitx-ham-apps/cubicsdr
    sudo chmod +x cubicsdr-icon-fix.sh 2>/dev/null || true
    sudo ./cubicsdr-icon-fix.sh 2>/dev/null || true
else
    echo "Note: CubicSDR icon fix skipped (~/sbitx-ham-apps/cubicsdr not found)"
fi

echo
echo "======================================"
echo "         Installation finished!"
echo "======================================"
echo
echo "Important:"
echo "  • Reboot recommended before starting CubicSDR"
echo "  • For SDRplay you need working API license"
