#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "This script needs to be run as root. Running as root..."
    exec sudo "$0" "$@"
    exit
fi

SYSTEM_DESKTOP_FILE1="/usr/share/applications/sBitx.desktop"
SYSTEM_DESKTOP_FILE2="/usr/share/applications/sb_launcher.desktop"
SYSTEM_DESKTOP_FILE3="/usr/share/applications/freedv_ptt.desktop"
USER_DESKTOP_FILE1="/home/pi/.local/share/applications/sBitx.desktop"
USER_DESKTOP_FILE2="/home/pi/.local/share/applications/sb_launcher.desktop"
USER_DESKTOP_FILE3="/home/pi/.local/share/applications/freedv_ptt.desktop"
USER_DESKTOP_FILE4="/home/pi/Desktop/freedv_ptt.desktop"
USER_DESKTOP_FILE5="/home/pi/Desktop/sBitx.desktop"
USER_DESKTOP_FILE6="/home/pi/Desktop/sb_launcher.desktop"
DESKTOP_SHORTCUT="/home/pi/Desktop/Hamradio_Shortcut.desktop"

DESKTOP_CONTENT1="[Desktop Entry]
Name=sBitx
Exec=/home/pi/sbitx/sbitx
Comment=
Terminal=false
Icon=/home/pi/sbitx/sbitx_icon.png
Categories=HamRadio;
Keywords=Hamradio;
Type=Application
Path=/home/pi/sbitx/"

DESKTOP_CONTENT2="[Desktop Entry]
Name=sBITX Apps
Exec=/home/pi/sBITX-toolbox/sb_launcher
Comment=
Terminal=false
Icon=/home/pi/sBITX-toolbox/icons/toolbox_icon.png
Categories=HamRadio;
Keywords=Hamradio;
Type=Application
Path=/home/pi/sBITX-toolbox/"

DESKTOP_CONTENT3="[Desktop Entry]
Name=FreeDV PTT
Exec=/home/pi/freedv_ptt/freedv_ptt
Comment=
Terminal=false
Icon=/home/pi/freedv_ptt/assets/freedvicon.gif
Categories=HamRadio;
Keywords=Hamradio;
Type=Application
Path=/home/pi/freedv_ptt"

recreate_desktop_file() {
    local file=$1
    local content=$2
    rm -f "$file"
    echo "$content" > "$file"
}

recreate_desktop_file "$SYSTEM_DESKTOP_FILE1" "$DESKTOP_CONTENT1"
recreate_desktop_file "$SYSTEM_DESKTOP_FILE2" "$DESKTOP_CONTENT2"
recreate_desktop_file "$SYSTEM_DESKTOP_FILE3" "$DESKTOP_CONTENT3"

rm -f "$USER_DESKTOP_FILE4"
rm -f "$USER_DESKTOP_FILE5"
rm -f "$USER_DESKTOP_FILE6"

mkdir -p "/home/pi/.local/share/applications"
recreate_desktop_file "$USER_DESKTOP_FILE1" "$DESKTOP_CONTENT1"
recreate_desktop_file "$USER_DESKTOP_FILE2" "$DESKTOP_CONTENT2"
recreate_desktop_file "$USER_DESKTOP_FILE3" "$DESKTOP_CONTENT3"


DESKTOP_SHORTCUT_CONTENT="[Desktop Entry]
Version=1.0
Type=Link
Name=Ham Radio
Comment=
URL=menu://applications/Hamradio
Icon=/usr/share/pixmaps/CQ.png"

recreate_desktop_file "$DESKTOP_SHORTCUT" "$DESKTOP_SHORTCUT_CONTENT"

wget -O "/home/pi/.config/lxpanel/LXDE-pi/panels/panel" "https://github.com/drexjj/sbitx-ham-apps/raw/main/sb64prodpatch0624/panel"

apt install audacity -y

echo "Changes made successfully.. Please reboot."
