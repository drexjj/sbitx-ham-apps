#!/bin/bash

# Define the file path
RC_LOCAL="/etc/rc.local"

# Check if the file exists
if [ ! -f "$RC_LOCAL" ]; then
    echo "File $RC_LOCAL does not exist."
    exit 1
fi

sudo sed -i 's/ timer_source=hw:0,0//g' "$RC_LOCAL"

echo "Removed 'timer_source=hw:0,0' from $RC_LOCAL."

rm -- "$0"
