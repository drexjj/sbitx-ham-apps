#!/bin/bash

# Update the package lists
echo "Updating package lists..."
sudo apt-get update

# Install dependencies
#echo "Installing dependencies..."
sudo apt-get -y install libqt6* qml6* binutils

# Create the /home/pi/droidstar directory
echo "Creating /home/pi/droidstar directory..."
sudo mkdir -p /home/pi/droidstar

# Expand droidstarsbitx.tar.gz to /home/pi/droidstar
echo "Expanding droidstarsbitx.tar.gz to /home/pi/droidstar..."
if [ -f "droidstarsbitx.tar.gz" ]; then
    sudo tar -xvzf droidstarsbitx.tar.gz -C /home/pi/droidstar
else
    echo "File droidstarsbitx.tar.gz not found! Please place it in the same directory as this script."
    exit 1
fi

# Change to /home/pi/droidstar directory
echo "Changing directory to /home/pi/droidstar..."
cd /home/pi/droidstar || exit 1

# Create a shortcut in the Ham Radio menu
echo "Creating a shortcut for Droidstar in the Ham Radio menu..."
sudo mkdir -p /usr/share/applications
sudo tee /usr/share/applications/droidstar.desktop > /dev/null <<EOL
[Desktop Entry]
GenericName=DroidStar Digital Radio Software
Name=DroidStar
Comment=DroidStar Digital Radio Software
Exec=/home/pi/droidstar/DroidStar
Terminal=false
Type=Application
Categories=HamRadio;
Icon=/home/pi/droidstar/images/droidstar.png
EOL

# Update desktop database if necessary
if command -v update-desktop-database > /dev/null 2>&1; then
    echo "Updating desktop database..."
    sudo update-desktop-database
fi

echo "Installation complete! You can find Droidstar in the Ham Radio menu."
