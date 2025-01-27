#!/bin/bash

echo "Starting DroidStar uninstallation..."

# Remove the /home/pi/droidstar directory
if [ -d "/home/pi/droidstar" ]; then
    echo "Removing /home/pi/droidstar directory..."
    sudo rm -rf /home/pi/droidstar
else
    echo "/home/pi/droidstar directory does not exist. Skipping..."
fi

# Remove the desktop shortcut from the Ham Radio menu
if [ -f "/usr/share/applications/droidstar.desktop" ]; then
    echo "Removing DroidStar desktop shortcut..."
    sudo rm /usr/share/applications/droidstar.desktop
else
    echo "DroidStar desktop shortcut not found. Skipping..."
fi

# Update desktop database if necessary
if command -v update-desktop-database > /dev/null 2>&1; then
    echo "Updating desktop database..."
    sudo update-desktop-database
fi

echo "DroidStar uninstallation complete."
