#!/bin/bash

# Exit on any error
set -e

echo "Starting installation process..."

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install dependencies
echo "Installing dependencies..."
sudo apt install -y libwxgtk3.2-dev libpulse-dev libliquid-dev libsoapysdr-dev \
    soapysdr-tools soapysdr-module-rtlsdr librtlsdr-dev libpulse-dev \
    libgtk-3-dev freeglut3-dev

# Install SoapySDR
echo "Installing SoapySDR..."
cd ~
git clone https://github.com/pothosware/SoapySDR.git
cd SoapySDR
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4
sudo make install
sudo ldconfig

# Install SDRplay API
echo "Installing SDRplay API..."
cd ~
wget https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.2.run
chmod +x SDRplay_RSP_API-Linux-3.15.2.run
echo "Running SDRplay installer (press Enter, then q, then y, then y when prompted)"
sudo ./SDRplay_RSP_API-Linux-3.15.2.run

# Install SoapySDRPlay
echo "Installing SoapySDRPlay..."
cd ~
git clone https://github.com/pothosware/SoapySDRPlay.git
cd SoapySDRPlay
mkdir build && cd build
cmake ..
make -j4
sudo make install

# Install SoapyRTLSDR
echo "Installing SoapyRTLSDR..."
cd ~
git clone https://github.com/pothosware/SoapyRTLSDR.git
cd SoapyRTLSDR
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4
sudo make install
sudo ldconfig

# Install CubicSDR
echo "Installing CubicSDR..."
cd ~
git clone https://github.com/cjcliffe/CubicSDR.git
cd CubicSDR
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
    -DUSE_HAMLIB=1
make -j4
sudo make install



# Install Icon Fix
echo "Fix CubicSDR Menu Icon..."

cd ~/sbitx-ham-apps/cubicsdr/
sudo ./cubicsdr-icon-fix.sh

echo "Installation complete!"
