#!/bin/bash

# Define the file path
RC_LOCAL="/etc/rc.local"

# Check if the file exists
if [ ! -f "$RC_LOCAL" ]; then
    echo "File $RC_LOCAL does not exist."
    exit 1
fi

sudo sed -i 's/modprobe snd-aloop enable=1,1,1 index=1,2,3 timer_source=hw:0,0/modprobe snd-aloop enable=1,1,1 index=1,2,3 timer_source=hw:0,0/' "$RC_LOCAL"

echo "Replacement complete in $RC_LOCAL."

rm -- "$0"
