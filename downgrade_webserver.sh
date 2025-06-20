#!/bin/bash

# Script to modify the HTTPS URL from https://sbitx.local:8443 to https://sbitx:8443 in /home/pi/sbitx/src/webserver.c and recompile

# Target file
FILE="/home/pi/sbitx/src/webserver.c"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE not found"
    exit 1
fi

# Check if file is writable
if [ ! -w "$FILE" ]; then
    echo "Error: File $FILE is not writable"
    exit 1
fi

# Create a backup of the original file
cp "$FILE" "${FILE}.bak"
echo "Created backup: ${FILE}.bak"

# Replace the URL using sed
# The pattern matches the specific line with sbitx.local:8443
sed -i "s|https://sbitx.local:8443|https://sbitx:8443|" "$FILE"

# Check if sed command was successful
if [ $? -eq 0 ]; then
    echo "Successfully updated URL to https://sbitx:8443 in $FILE"
else
    echo "Error: Failed to update URL in $FILE"
    exit 1
fi

# Verify the change
if grep -q "https://sbitx:8443" "$FILE"; then
    echo "Verification: URL change confirmed in $FILE"
else
    echo "Warning: Could not verify URL change in $FILE"
fi

# Change to sbitx directory and recompile
cd /home/pi/sbitx
if [ $? -eq 0 ]; then
    echo "Changed to /home/pi/sbitx directory"
    ./build sbitx
    if [ $? -eq 0 ]; then
        echo "Successfully recompiled sbitx"
    else
        echo "Error: Failed to recompile sbitx"
        exit 1
    fi
else
    echo "Error: Could not change to /home/pi/sbitx directory"
    exit 1
fi
