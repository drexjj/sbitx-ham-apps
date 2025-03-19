#!/bin/bash

# Define the file path
DESKTOP_FILE="/usr/local/share/applications/CubicSDR.desktop"

# Check if file exists
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Error: File $DESKTOP_FILE not found!"
    exit 1
fi

# Check if we have write permissions
if [ ! -w "$DESKTOP_FILE" ]; then
    echo "Error: No write permission for $DESKTOP_FILE. Run with sudo?"
    exit 1
fi

# Create a temporary file
TEMP_FILE=$(mktemp)

# Replace the Icon line and keep everything else the same
sed 's|Icon=/usr/local/share/cubicsdr/CubicSDR|Icon=/usr/local/share/cubicsdr/CubicSDR.png|' "$DESKTOP_FILE" > "$TEMP_FILE"

# Copy the original file's permissions and ownership to the temp file
chmod --reference="$DESKTOP_FILE" "$TEMP_FILE"
chown --reference="$DESKTOP_FILE" "$TEMP_FILE"

# Move the temporary file to replace the original
mv -f "$TEMP_FILE" "$DESKTOP_FILE"

echo "Desktop entry file updated successfully!"
echo "New contents:"
cat "$DESKTOP_FILE"