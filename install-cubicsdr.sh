#!/bin/bash

# Exit on any error
set -e

echo "Starting installation process..."

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install dependencies
echo "Installing dependencies..."
sudo apt install -y \
    libwxgtk3.2-dev \
    libpulse-dev \
    libasound2-dev \
    libportaudio2 \
    portaudio19-dev \
    libliquid-dev \
    libsoapysdr-dev \
    soapysdr-tools \
    soapysdr-module-rtlsdr \
    librtlsdr-dev \
    libgtk-3-dev \
    freeglut3-dev \
    cmake \
    git

# Install SoapySDR (depecrated)
#echo "Installing SoapySDR..."
#cd ~
#rm -rf SoapySDR
#git clone https://github.com/pothosware/SoapySDR.git
#cd SoapySDR
#mkdir -p build && cd build
#cmake .. -DCMAKE_BUILD_TYPE=Release
#make -j4
#sudo make install
#sudo ldconfig

# Install SDRplay API
echo "Installing SDRplay API..."
cd ~
wget -nc https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.2.run
chmod +x SDRplay_RSP_API-Linux-3.15.2.run
echo "Running SDRplay installer (press Enter, then q, then y, then y when prompted)"
sudo ./SDRplay_RSP_API-Linux-3.15.2.run

# Install SoapySDRPlay
echo "Installing SoapySDRPlay..."
cd ~
rm -rf SoapySDRPlay
git clone https://github.com/pothosware/SoapySDRPlay.git
cd SoapySDRPlay
mkdir -p build && cd build
cmake ..
make -j4
sudo make install
sudo ldconfig

################################################################################
# Don't build SoapyRTLSDR since we install soapysdr-module-rtlsdr from # the OS 
# repositories above
################################################################################
# # Install SoapyRTLSDR
# echo "Installing SoapyRTLSDR..."
# cd ~
# rm -rf SoapyRTLSDR
# git clone https://github.com/pothosware/SoapyRTLSDR.git
# cd SoapyRTLSDR
# mkdir -p build && cd build
# cmake .. -DCMAKE_BUILD_TYPE=Release
# make -j4
# sudo make install
sudo ldconfig

# Install CubicSDR WITH AUDIO SUPPORT
echo "Installing CubicSDR (with ALSA / Audio IQ support)..."
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

# Install Icon Fix
echo "Fix CubicSDR Menu Icon..."
cd ~/sbitx-ham-apps/cubicsdr
sudo chmod +x *
sudo ./cubicsdr-icon-fix.sh

echo "Installation complete!"
echo
echo "IMPORTANT:"
echo "Reboot or log out/in before starting CubicSDR."
