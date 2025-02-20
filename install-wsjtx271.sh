#!/bin/bash

# Ensure the script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or use sudo"
    exec sudo "$0" "$@"
    exit 1
fi

# Update package list
apt update

# Remove conflicting wsjtx-doc package if installed
dpkg -l | grep -q wsjtx-doc && apt remove -y wsjtx-doc
dpkg -l | grep -q wsjtx-data && apt remove -y wsjtx-data


# Install required dependencies
apt install -y libqt5multimedia5 libqt5serialport5 libqt5network5 libfftw3-single3 libboost-all-dev

#change directory
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
