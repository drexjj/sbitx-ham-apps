# Set TOP if it isn't already set in the environment
: "${TOP:=${HOME}}"
# Set JFLAG if it isn't already set in the environment
: "${JFLAG:=-j$(nproc)}"

set -ex

echo \#########################################################################
echo "deskhpsdr"
echo \#########################################################################

sudo apt install -y \
 libwebkit2gtk-4.0-dev libwebkit2gtk-4.1-dev libpcap-dev libjson-c-dev 

pushd ${TOP}
[ ! -d deskhpsdr ] && git clone https://github.com/dl1bz/deskhpsdr deskhpsdr
pushd deskhpsdr
git pull
# blast the config we want into make.config.deskhpsdr
# we can't tell anything about the state of the file or its history
# because the maintainer has done:
#   $ git update-index --assume-unchanged make.config.deskhpsdr
cat > make.config.deskhpsdr << EOF
TCI=ON
GPIO=OFF
MIDI=ON
SATURN=OFF
USBOZY=OFF
SOAPYSDR=ON
STEMLAB=OFF
EXTENDED_NR=
AUDIO=PULSE
ATU=OFF
COPYMODE=OFF
AUTOGAIN=OFF
REGION1=OFF
WMAP=OFF
EOF
# scavanging LINUX/libinstall.txt for the parts we need
export TARGET="${TOP}/deskhpsdr/LINUX"
rm -f $HOME/Desktop/deskhpsdr.desktop
rm -f $HOME/.local/share/applications/deskhpsdr.desktop
cat <<EOT > $TARGET/deskhpsdr.sh
cd $TARGET
$TARGET/../deskhpsdr >log 2>&1
EOT
chmod +x $TARGET/deskhpsdr.sh
cat <<EOT > $TARGET/deskhpsdr.desktop
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Name[en_US]=deskHPSDR
Path=$TARGET
Exec=$TARGET/deskhpsdr.sh
Icon=$TARGET/hpsdr_icon.png
Name=deskHPSDR
EOT
cp $TARGET/deskhpsdr.desktop $HOME/Desktop
mkdir -p $HOME/.local/share/applications
cp $TARGET/deskhpsdr.desktop $HOME/.local/share/applications
cp release/deskhpsdr/hpsdr.png $TARGET
cp release/deskhpsdr/hpsdr_icon.png $TARGET

# Patch the soapy discovery code to set the sample rate for sbitx
if git diff --quiet src/soapy_discovery.c; then
    # generate the patch for the code
    patch -p1 << EOF
diff --git a/src/soapy_discovery.c b/src/soapy_discovery.c
index ce1d179..b0902b9 100644
--- a/src/soapy_discovery.c
+++ b/src/soapy_discovery.c
@@ -126,6 +126,8 @@ static void get_info(char *driver) {
 
   if (strcmp(driver, "rtlsdr") == 0) {
     sample_rate = 1536000;
+  } else if (strcmp(driver, "sbitx") == 0) {
+    sample_rate = 48000;
   } else if (strcmp(driver, "radioberry") == 0) {
     sample_rate = 48000;
   }
EOF
else
    echo "src/soapy_discovery.c is already modified"
fi

# (re-)build it!
make ${JFLAG} clean
make ${JFLAG} 
# do NOT install it!

popd  # deskhpsdr
popd  # $TOP

