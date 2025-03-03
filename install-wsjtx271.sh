#!/bin/bash

# Ensure the script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or use sudo"
    exec sudo "$0" "$@"
    exit 1
fi

# Update package list
apt update

# Install required dependencies
apt install -y libqt5multimedia5 libqt5serialport5 libqt5network5 libfftw3-single3 libboost-all-dev

# Change directory to wsjtx
cd wsjtx || { echo "Directory wsjtx not found!"; exit 1; }

# List available WSJT-X versions
wsjtx_files=(wsjtx-*.deb)
if [ ${#wsjtx_files[@]} -eq 0 ]; then
    echo "No WSJT-X .deb files found!"
    exit 1
fi

echo "Available WSJT-X packages:"
for i in "${!wsjtx_files[@]}"; do
    echo "$((i+1))) ${wsjtx_files[i]}"
done

echo "Please select the number of the WSJT-X version you want to install:"
read -r selection

# Validate input
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#wsjtx_files[@]} ]; then
    echo "Invalid selection! Exiting."
    exit 1
fi

# Install selected WSJT-X package with force overwrite
selected_file="${wsjtx_files[selection-1]}"
echo "Installing $selected_file..."
dpkg -i --force-overwrite "$selected_file"

# Fix any missing dependencies
apt --fix-broken install -y

# Verify installation
if dpkg -l | grep -q wsjtx; then
    echo "WSJT-X installed successfully."
else
    echo "WSJT-X installation failed. Check errors above."
fi
