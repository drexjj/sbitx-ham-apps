#!/bin/bash

# Exit on any error
set -e

echo "Starting installation process..."



# Install Icon Fix
echo "Fix CubicSDR Menu Icon..."
cd ~
cd ~/sbitx-ham-apps/cubicsdr
sudo chmod +x *
sudo ./cubicsdr-icon-fix.sh

echo "Installation complete!"
