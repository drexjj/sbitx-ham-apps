#!/bin/bash

# Ensure the script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or use sudo"
    exec sudo "$0" "$@"
    exit 1
fi

# Update package list
apt update

# Remove conflicting wsjtx-doc and wsjtx-data packages if installed
dpkg -l | grep -q wsjtx-doc && apt remove -y wsjtx-doc
dpkg -l | grep -q wsjtx-data && apt remove -y wsjtx-data

# Install required dependencies
apt install -y libqt5multimedia5 libqt5serialport5 libqt5network5 libfftw3-single3 libboost-all-dev

# Change directory to wsjtx
cd wsjtx || { echo "Directory wsjtx not found!"; exit 1; }

# List available WSJT-X versions
echo "Available WSJT-X packages:"
ls wsjtx-*.deb 2>/dev/null || { echo "No WSJT-X .deb files found!"; exit 1; }

echo "Please enter the WSJT-X version you want to install:"
read -r wsjtx_version

# Check if the selected package exists
if [[ ! -f "$wsjtx_version" ]]; then
    echo "Error: Selected package not found!"
    exit 1
fi

# Install selected WSJT-X package
dpkg -i "$wsjtx_version"

# Fix any missing dependencies
apt --fix-broken install -y

# Verify installation
if dpkg -l | grep -q wsjtx; then
    echo "WSJT-X installed successfully."
else
    echo "WSJT-X installation failed. Check errors above."
fi
