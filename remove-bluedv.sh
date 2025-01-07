#!/bin/bash

# Remove the BlueDV directory
echo "Removing /home/pi/bluedv directory..."
if [ -d "/home/pi/bluedv" ]; then
    sudo rm -rf /home/pi/bluedv
    echo "/home/pi/bluedv directory removed."
else
    echo "/home/pi/bluedv directory not found."
fi

# Remove the BlueDV desktop shortcut
echo "Removing BlueDV desktop shortcut..."
if [ -f "/usr/share/applications/bluedv.desktop" ]; then
    sudo rm /usr/share/applications/bluedv.desktop
    echo "BlueDV desktop shortcut removed."
else
    echo "BlueDV desktop shortcut not found."
fi

# Check if mono-complete should be uninstalled
read -p "Do you want to remove mono-complete as well? (y/n): " remove_mono
if [[ $remove_mono == "y" || $remove_mono == "Y" ]]; then
    echo "Removing mono-complete..."
    sudo apt purge mono-complete -y
    sudo apt autoremove -y
    echo "mono-complete removed."
else
    echo "mono-complete will remain installed."
fi

# Clean up package lists
echo "Cleaning up package lists..."
sudo apt clean

echo "Uninstallation complete!"
