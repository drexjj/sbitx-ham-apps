#!/bin/bash

# Self-elevate to root if not already running as root
if [[ $(id -u) -ne 0 ]]; then
    echo "Re-running this script with sudo privileges..."
    exec sudo bash "$0" "$@"
fi

# Step 1: Install and configure Qtel
echo "Updating repositories and installing Qtel..."
apt-get update
apt-get install -y qtel

# Configuration parameters
USER="pi"
QTEL_CONF="/home/$USER/.config/SvxLink/Qtel.conf"
QTEL_DIR=$(dirname "$QTEL_CONF")

# Ensure the configuration directory exists and is owned by the user
echo "Ensuring configuration directory exists..."
mkdir -p "$QTEL_DIR"
chown -R $USER:$USER "$QTEL_DIR"

# Create/overwrite the Qtel configuration file as the user 'pi'
echo "Creating Qtel configuration file..."
sudo -u "$USER" bash -c "cat > '$QTEL_CONF' << EOF
[General]
BindAddress=
Bookmarks=*ECHOTEST*
Callsign=MYCALL
CardSampleRate=48000
ChatEncoding=ISO8859-1
ConnectSound=/usr/share/qtel/sounds/connect.raw
DirectoryServers=server1.echolink.org
HSplitterSizes=256, 597
IncomingViewColumnSizes=100, 100, 107
Info=\"Running Qtel, an EchoLink client for Linux\"
ListRefreshTime=5
Location=
MainWindowSize=@Size(877 501)
MicAudioDevice=alsa:plughw:0
Name=MYNAME
Password=MYPASSWORD
ProxyEnabled=false
ProxyPassword=
ProxyPort=8100
ProxyServer=
SpkrAudioDevice=alsa:plughw:0
StartAsBusy=false
StationViewColumnSizes=100, 100, 100, 100, 100, 100
UseFullDuplex=true
VSplitterSizes=193, 229
EOF"

# Set correct permissions for the configuration file
chown $USER:$USER "$QTEL_CONF"

echo "Qtel has been installed and configured successfully."

# Step 2: Create the .desktop file for Qtel Control
APP_PATH="/home/pi/sbitx-ham-apps/qtel/qtel-control"
ICON_PATH="/home/pi/sbitx-ham-apps/qtel/qtel.png"
DESKTOP_FILE="/home/pi/.local/share/applications/qtel-control.desktop"

# Create the .desktop file
echo "Creating the menu shortcut..."
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=Qtel Control
Comment=Ham Radio application for managing Qtel
Exec=$APP_PATH
Icon=$ICON_PATH
Terminal=false
Categories=HamRadio;Utility;
EOF

# Set the executable permissions
chmod +x "$DESKTOP_FILE"
chmod +x "/home/pi/sbitx-ham-apps/qtel/qtel-control"

echo "Menu shortcut created at $DESKTOP_FILE"
