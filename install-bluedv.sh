#!/bin/bash

# Update the package lists
echo "Updating package lists..."
sudo apt-get update

# Install mono-complete
echo "Installing mono-complete..."
sudo apt-get -y install mono-complete

# Create the /home/pi/bluedv directory
echo "Creating /home/pi/bluedv directory..."
sudo mkdir -p /home/pi/bluedv

# Expand bluedvsbitx.tar.gz to /home/pi/bluedv
echo "Expanding bluedvsbitx.tar.gz to /home/pi/bluedv..."
if [ -f "bluedvsbitx.tar.gz" ]; then
    sudo tar -xvzf bluedvsbitx.tar.gz -C /home/pi/bluedv
else
    echo "File bluedvsbitx.tar.gz not found! Please place it in the same directory as this script."
    exit 1
fi

# Change to /home/pi/bluedv directory
echo "Changing directory to /home/pi/bluedv..."
cd /home/pi/bluedv || exit 1

# Create a shortcut in the Ham Radio menu
echo "Creating a shortcut for BlueDV in the Ham Radio menu..."
sudo mkdir -p /usr/share/applications
sudo tee /usr/share/applications/bluedv.desktop > /dev/null <<EOL
[Desktop Entry]
GenericName=BlueDV HotSpot Software
Name=BlueDV
Comment=BlueDV HotSpot Software
Exec=sh -c "cd /home/pi/bluedv/; sudo mono BlueDV.exe"
Terminal=false
Type=Application
Categories=HamRadio;
Icon=/home/pi/bluedv/BlueDV.png
EOL

# Update desktop database if necessary
if command -v update-desktop-database > /dev/null 2>&1; then
    echo "Updating desktop database..."
    sudo update-desktop-database
fi

echo "Installation complete! You can find BlueDV in the Ham Radio menu."
