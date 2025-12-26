#!/bin/bash
# Exit on any error
set -e

echo "================================================================="
echo "     sBitx CubicSDR drivers & applications installer"
echo "================================================================="
echo

# Default: everything off - user must choose
INSTALL_SOAPYSDR="n"
INSTALL_CUBICSDR="n"
INSTALL_SDRPLAY="n"
INSTALL_RTLSDR="n"
INSTALL_SBITX_SOAPY="n"

# Command line arguments support
for arg in "$@"; do
    case "$arg" in
        soapy|soapysdr)      INSTALL_SOAPYSDR="y" ;;
        cubic|cubicsdr)      INSTALL_CUBICSDR="y" ;;
        sdrplay)             INSTALL_SDRPLAY="y" ;;
        rtl|rtlsdr)          INSTALL_RTLSDR="y" ;;
        sbitx|sbitxsoapy)    INSTALL_SBITX_SOAPY="y" ;;
        drivers)             INSTALL_SDRPLAY="y"; INSTALL_RTLSDR="y"; INSTALL_SBITX_SOAPY="y" ;;
        all)                 INSTALL_SOAPYSDR="y"; INSTALL_CUBICSDR="y"
                             INSTALL_SDRPLAY="y"; INSTALL_RTLSDR="y"; INSTALL_SBITX_SOAPY="y" ;;
    esac
done

# Interactive selection if no arguments were meaningful
if [[ "$INSTALL_SOAPYSDR$INSTALL_CUBICSDR$INSTALL_SDRPLAY$INSTALL_RTLSDR$INSTALL_SBITX_SOAPY" == "nnnnn" ]]; then
    echo "Select components to install / update (y/N):"
    echo
    read -p "SoapySDR core                  [y/N]: " -n 1 -r SOAPS_ANS     && echo
    read -p "RTL-SDR support (SoapyRTLSDR)  [y/N]: " -n 1 -r RTLSD_ANS     && echo
    read -p "SDRplay support (API+module)   [y/N]: " -n 1 -r SDRPL_ANS     && echo
    read -p "sbitx experimental Soapy driver[y/N]: " -n 1 -r SBITX_ANS     && echo
    read -p "CubicSDR application           [y/N]: " -n 1 -r CUBIC_ANS     && echo

    [[ $SOAPS_ANS  =~ ^[Yy]$ ]] && INSTALL_SOAPYSDR="y"
    [[ $RTLSD_ANS  =~ ^[Yy]$ ]] && INSTALL_RTLSDR="y"
    [[ $SDRPL_ANS  =~ ^[Yy]$ ]] && INSTALL_SDRPLAY="y"
    [[ $SBITX_ANS  =~ ^[Yy]$ ]] && INSTALL_SBITX_SOAPY="y"
    [[ $CUBIC_ANS  =~ ^[Yy]$ ]] && INSTALL_CUBICSDR="y"
fi

echo
echo "Selected:"
echo "  • SoapySDR core ............ $( [[ $INSTALL_SOAPYSDR == "y" ]]     && echo "YES" || echo "no" )"
echo "  • RTL-SDR module ........... $( [[ $INSTALL_RTLSDR == "y" ]]       && echo "YES" || echo "no" )"
echo "  • SDRplay (API+module) ..... $( [[ $INSTALL_SDRPLAY == "y" ]]      && echo "YES" || echo "no" )"
echo "  • sbitx Soapy driver ....... $( [[ $INSTALL_SBITX_SOAPY == "y" ]]  && echo "YES" || echo "no" )"
echo "  • CubicSDR ................. $( [[ $INSTALL_CUBICSDR == "y" ]]     && echo "YES" || echo "no" )"
echo
read -p "Continue? (Enter = yes / Ctrl+C = cancel) "
echo

echo "Updating system & installing common dependencies..."
sudo apt update -y
sudo apt install -y \
    libwxgtk3.2-dev libpulse-dev libasound2-dev portaudio19-dev \
    libportaudio2 libliquid-dev libfftw3-dev libgtk-3-dev freeglut3-dev \
    cmake git build-essential pkg-config libusb-1.0-0-dev

# ── 1. SoapySDR core ─────────────────────────────────────────────────────────
# Almost always needed — we install it if any driver or CubicSDR is selected
if [[ $INSTALL_SOAPYSDR == "y" || $INSTALL_RTLSDR == "y" || $INSTALL_SDRPLAY == "y" || $INSTALL_SBITX_SOAPY == "y" || $INSTALL_CUBICSDR == "y" ]]; then
    echo "┌──────────────────────────────────────────────┐"
    echo "│         Installing / Updating SoapySDR       │"
    echo "└──────────────────────────────────────────────┘"
    cd ~
    rm -rf SoapySDR
    git clone https://github.com/pothosware/SoapySDR.git
    cd SoapySDR
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j4
    sudo make install
    sudo ldconfig
fi

# ── 2. Driver modules (depend on SoapySDR) ───────────────────────────────────
if [[ $INSTALL_RTLSDR == "y" ]]; then
    echo "┌──────────────────────────────────────────────┐"
    echo "│         Installing SoapyRTLSDR module        │"
    echo "└──────────────────────────────────────────────┘"
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

if [[ $INSTALL_SDRPLAY == "y" ]]; then
    echo "┌──────────────────────────────────────────────┐"
    echo "│         Installing SDRplay API + module      │"
    echo "└──────────────────────────────────────────────┘"
    cd ~
    wget -nc https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.2.run
    chmod +x SDRplay_RSP_API-Linux-3.15.2.run
    echo "→ SDRplay installer will open — follow prompts (Enter → q → y → y)"
    sleep 3
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

if [[ $INSTALL_SBITX_SOAPY == "y" ]]; then
    echo "┌──────────────────────────────────────────────┐"
    echo "│      Installing sbitx experimental driver    │"
    echo "└──────────────────────────────────────────────┘"
    if [[ ! -d ~/sbitx-ham-apps/soapy2sbitx ]]; then
        echo "ERROR: ~/sbitx-ham-apps/soapy2sbitx directory not found!"
        echo "       Please clone sbitx-ham-apps repo first."
        exit 1
    fi
    cd ~/sbitx-ham-apps/soapy2sbitx
    rm -rf build 2>/dev/null || true
    mkdir -p build && cd build
    cmake ..
    make -j4
    sudo make install
    sudo ldconfig
    git clone https://github.com/Rhizomatica/sbitx-core.git
    cd sbitx-core
    cp ~/sbitx-ham-apps/soapy2sbitx/sbitx_ctl.c ~/sbitx-core
    mkdir -p build && cd build
    cmake ..
    make -j4
    sudo make install
    sudo ldconfig
    
fi

# ── 3. Application (depends on SoapySDR + drivers) ───────────────────────────
if [[ $INSTALL_CUBICSDR == "y" ]]; then
    echo "┌──────────────────────────────────────────────┐"
    echo "│             Installing CubicSDR              │"
    echo "└──────────────────────────────────────────────┘"
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
fi

# Icon fix (optional)
if [[ -f ~/sbitx-ham-apps/cubicsdr/cubicsdr-icon-fix.sh ]]; then
    echo "Applying CubicSDR icon fix..."
    cd ~/sbitx-ham-apps/cubicsdr
    sudo chmod +x cubicsdr-icon-fix.sh
    sudo ./cubicsdr-icon-fix.sh || true
fi

echo
echo "================================================================="
echo "                        FINISHED"
echo "================================================================="
echo " Recommended:"
echo "   • Reboot"
echo "   • Check devices:     SoapySDRUtil --find"
echo "   • Run:               CubicSDR"
