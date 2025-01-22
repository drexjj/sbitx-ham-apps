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

# Optional: Remove dependencies
read -p "Do you want to remove the installed dependencies (libqt6*, qml6*, binutils)? [y/N]: " remove_deps
if [[ "$remove_deps" =~ ^[Yy]$ ]]; then
    echo "Removing dependencies..."
    sudo apt-get -y purge libqt6* qml6* binutils
    sudo apt-get -y autoremove
fi

echo "DroidStar uninstallation complete."
