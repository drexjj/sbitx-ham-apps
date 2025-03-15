#!/bin/bash

# Exit on any error
set -e

# Function to check if a command succeeded
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    fi
}

echo "Starting CubicSDR installation..."

# Extract the SDR software archive
cd ~/sbitx-ham-apps/cubicsdr/
echo "Extracting sdr_software.tar.gz..."
tar -xzvf sdr_software.tar.gz
check_status "Extraction"

# Update package list and install dependencies
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y cmake git build-essential librtlsdr-dev libgl1-mesa-dev libpng-dev libjpeg-dev libtiff-dev zlib1g-dev
check_status "Dependency installation"

# Install SoapySDR
echo "Installing SoapySDR..."
cd ~/SoapySDR/build
sudo make install
sudo ldconfig
check_status "SoapySDR installation"

# Install liquid-dsp
echo "Installing liquid-dsp..."
cd ~/liquid-dsp/build
sudo make install
sudo ldconfig
check_status "liquid-dsp installation"

# Install wxWidgets
echo "Installing wxWidgets..."
cd ~/wxWidgets-3.2.1
sudo make install
check_status "wxWidgets installation"

# Install CubicSDR
echo "Installing CubicSDR..."
cd ~/CubicSDR/build
cmake .. -DwxWidgets_CONFIG_EXECUTABLE=~/Develop/wxWidgets-staticlib/bin/wx-config
check_status "CubicSDR cmake configuration"
make
check_status "CubicSDR make"
sudo make install
check_status "CubicSDR installation"

# Install SoapyRTLSDR
echo "Installing SoapyRTLSDR..."
cd ~/SoapyRTLSDR/build
cmake ..
make
sudo make install
sudo ldconfig
check_status "SoapyRTLSDR installation"

# Install SoapySDRPlay
echo "Installing SoapySDRPlay..."
cd ~/SoapySDRPlay/build
cmake ..
make
sudo make install
sudo ldconfig
check_status "SoapySDRPlay installation"

# Fix desktop file
echo "Fixing desktop file..."
DESKTOP_FILE="/usr/local/share/applications/CubicSDR.desktop"

if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Warning: Desktop file $DESKTOP_FILE not found! Skipping desktop file update."
else
    if [ ! -w "$DESKTOP_FILE" ]; then
        echo "Error: No write permission for $DESKTOP_FILE. Please run with sudo."
        exit 1
    fi

    TEMP_FILE=$(mktemp)
    sed 's|Icon=/usr/local/share/cubicsdr/CubicSDR|Icon=/usr/local/share/cubicsdr/cubicsdr.png|' "$DESKTOP_FILE" > "$TEMP_FILE"
    check_status "Desktop file modification"
    mv "$TEMP_FILE" "$DESKTOP_FILE"
    check_status "Desktop file update"
    
    echo "Desktop entry file updated successfully!"
    echo "New contents:"
    cat "$DESKTOP_FILE"
fi

echo "Installation completed successfully!"
