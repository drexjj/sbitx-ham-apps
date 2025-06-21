#!/bin/bash

# Install gpsd-py3 package
sudo pip3 install gpsd-py3 --break-system-packages

# Add PYTHONPATH to ~/.bashrc
echo 'export PYTHONPATH=/usr/lib/python3/dist-packages:/usr/local/lib/python3/dist-packages:$PYTHONPATH' >> ~/.bashrc

# Source ~/.bashrc to apply changes
source ~/.bashrc

# Replace the DEVICES line in /etc/default/gpsd
sudo sed -i 's/DEVICES=""/DEVICES="\/dev\/ttyACM0"/' /etc/default/gpsd

# Restart gpsd service
sudo systemctl restart gpsd

echo "Script completed. Please verify gpsd status with with 'xgps'."
