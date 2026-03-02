#!/bin/bash

# Ensure we are in the script's directory
cd "$(dirname "$0")"

# 1. Find SDK Path (Adjust if yours is different!)
SDK_HOME=$(find ~/.Garmin/ConnectIQ/Sdks/ -name "connectiq-sdk-lin-*" -type d 2>/dev/null | sort -r | head -n 1)
if [ -z "$SDK_HOME" ]; then
    echo "Could not auto-detect SDK in ~/.Garmin/ConnectIQ/Sdks/"
    echo "Please find where you downloaded the SDK and set SDK_HOME manually in this script."
    exit 1
fi

BIN="$SDK_HOME/bin"
DEVICE="fenix7" # Fenix 7 Sapphire Solar

echo "Using SDK: $SDK_HOME"

# 2. Compile
echo "Compiling..."
mkdir -p bin
"$BIN/monkeyc" \
    -d $DEVICE \
    -f monkey.jungle \
    -o bin/SmartLightApp.prg \
    -y developer_key.der

if [ $? -ne 0 ]; then
    echo "Compilation Failed!"
    exit 1
fi

# 3. Simulate
echo "Starting Simulator..."
"$BIN/connectiq" &
PID=$!
sleep 5

"$BIN/monkeydo" bin/SmartLightApp.prg $DEVICE
