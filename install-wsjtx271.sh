#!/bin/bash

# Ensure the script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
    exit 1
fi

# Update package list
apt update

# Install required dependencies
apt install -y \
    libgfortran5 libgfortran4 libgfortran3 libfftw3-single3 libgomp1 \
    libqt5serialport5 libqt5multimedia5-plugins libqt5widgets5 libqt5network5 \
    libqt5printsupport5 libqt5sql5-sqlite libusb-1.0-0 \
    libboost-log1.62.0 libboost-log1.65.1 libboost-log1.67.0 libboost-log1.71.0 \
    libboost-log1.74.0 libboost-filesystem1.74.0 libboost-thread1.74.0 \
    libc6 libfftw3-single3 libgcc-s1 libgfortran5 libgomp1 libqt5core5a \
    libqt5gui5 libqt5gui5-gles libqt5multimedia5 libqt5network5 \
    libqt5printsupport5 libqt5serialport5 libqt5sql5 libqt5widgets5 \
    libstdc++6 libusb-1.0-0

# change directory
cd wsjtx

# Install WSJT-X package
dpkg -i wsjtx-2.7.1-devel_improved_AL_PLUS_241014-RC7_Rpi_arm64.deb

# Fix any missing dependencies
apt --fix-broken install -y

# Verify installation
if dpkg -l | grep -q wsjtx; then
    echo "WSJT-X installed successfully."
else
    echo "WSJT-X installation failed. Check errors above."
fi
