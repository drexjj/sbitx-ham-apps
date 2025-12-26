#!/bin/bash
# Uninstall / Cleanup script for sbitx/CubicSDR/SoapySDR related components
# Use with caution! This script removes installed files, git clones, etc.
set -e

echo "================================================================="
echo "     SoapySDR Removal & Cleanup Script"
echo "     (removes what the installation script usually installs)"
echo "================================================================="
echo
echo "WARNING: This script will remove:"
echo "  • SoapySDR core installation"
echo "  • SoapyRTLSDR, SoapySDRPlay modules"
echo
read -p "Are you sure you want to proceed with removal? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo
echo "Starting cleanup..."

# ── 1. Remove installed SoapySDR modules ─────────────────────────────────────
echo "Removing installed SoapySDR modules..."

# SoapyRTLSDR
sudo rm -f /usr/local/lib/SoapySDR/modules*/*RTLSDR* 2>/dev/null || true

# SoapySDRPlay
sudo rm -f /usr/local/lib/SoapySDR/modules*/*SDRplay* 2>/dev/null || true

# ── 2. Remove SoapySDR core ──────────────────────────────────────────────────
echo "Removing SoapySDR core installation..."
sudo rm -rf /usr/local/lib/libSoapySDR*             2>/dev/null || true
sudo rm -rf /usr/local/lib/cmake/SoapySDR           2>/dev/null || true
sudo rm -rf /usr/local/include/SoapySDR             2>/dev/null || true
sudo rm -rf /usr/local/share/cmake/SoapySDR         2>/dev/null || true
sudo rm -f  /usr/local/bin/SoapySDRUtil             2>/dev/null || true

# ── 3. Remove CubicSDR ───────────────────────────────────────────────────────
#echo "Removing CubicSDR..."
#sudo rm -f /usr/local/bin/CubicSDR*                 2>/dev/null || true
#sudo rm -rf /usr/local/share/CubicSDR               2>/dev/null || true
#sudo rm -rf /usr/local/lib/CubicSDR*                2>/dev/null || true

# ── 4. Remove SDRplay API (most common install locations) ────────────────────
echo "Removing SDRplay API..."
sudo rm -rf /usr/lib/librsp*                        2>/dev/null || true
sudo rm -rf /usr/include/librsp*                    2>/dev/null || true
sudo rm -rf /usr/local/lib/librsp*                  2>/dev/null || true
sudo rm -rf ~/SDRplay                               2>/dev/null || true
sudo rm -f  /usr/bin/rsp_tcp                        2>/dev/null || true   # if installed

# Try to remove the .run installer file too
rm -f ~/SDRplay_RSP_API-Linux-*.run                 2>/dev/null || true

# ── 5. Remove cloned git repositories ────────────────────────────────────────
echo "Removing downloaded git repositories..."
cd ~
rm -rf SoapySDR             2>/dev/null || true
rm -rf SoapyRTLSDR          2>/dev/null || true
rm -rf SoapySDRPlay         2>/dev/null || true

# ── 6. Final ldconfig & summary ──────────────────────────────────────────────
echo "Updating library cache..."
sudo ldconfig 2>/dev/null || true

echo
echo "================================================================="
echo "                  Cleanup finished"
echo "================================================================="
echo
echo "Reboot recommended after cleanup."
