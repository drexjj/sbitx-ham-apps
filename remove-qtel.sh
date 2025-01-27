#!/bin/bash

# Self-elevate to root if not already running as root
if [[ $(id -u) -ne 0 ]]; then
    echo "Re-running this script with sudo privileges..."
    exec sudo bash "$0" "$@"
fi

echo "Removing Qtel and dependencies..."
apt-get purge -y qtel
apt-get autoremove -y
apt-get autoclean -y

# Configuration parameters
USER="pi"
QTEL_CONF="/home/$USER/.config/SvxLink/Qtel.conf"
QTEL_DIR=$(dirname "$QTEL_CONF")

echo "Removing Qtel configuration files..."
if [[ -f "$QTEL_CONF" ]]; then
    rm -f "$QTEL_CONF"
    echo "Removed: $QTEL_CONF"
fi

if [[ -d "$QTEL_DIR" ]]; then
    rm -rf "$QTEL_DIR"
    echo "Removed directory: $QTEL_DIR"
fi

DESKTOP_FILE="/home/$USER/.local/share/applications/qtel-control.desktop"
APP_DIR="/home/pi/sbitx-ham-apps/qtel"
APP_PATH="$APP_DIR/qtel-control"
ICON_PATH="$APP_DIR/qtel.png"

echo "Removing application and shortcut files..."
if [[ -f "$DESKTOP_FILE" ]]; then
    rm -f "$DESKTOP_FILE"
    echo "Removed: $DESKTOP_FILE"
fi

if [[ -f "$APP_PATH" ]]; then
    rm -f "$APP_PATH"
    echo "Removed: $APP_PATH"
fi

if [[ -f "$ICON_PATH" ]]; then
    rm -f "$ICON_PATH"
    echo "Removed: $ICON_PATH"
fi

if [[ -d "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
    echo "Removed directory: $APP_DIR"
fi

echo "Qtel and its associated files have been removed successfully."
