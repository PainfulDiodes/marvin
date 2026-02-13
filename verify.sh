#!/usr/bin/env bash

# Read back the EEPROM contents for verification.
# Auto-detects whether an AT28C256 or AT28C64B is present.
#
# Usage: ./verify.sh

set -e

CANDIDATES=("AT28C256" "AT28C64B")

# Check programmer is connected
if ! minipro -k 2>/dev/null; then
    echo "Error: No programmer detected"
    exit 1
fi

# Probe each candidate device by reading its chip ID
DETECTED=""
for device in "${CANDIDATES[@]}"; do
    if minipro -p "$device" -D 2>/dev/null; then
        DETECTED="$device"
        break
    fi
done

if [ -z "$DETECTED" ]; then
    echo "Error: Could not identify device. Tried: ${CANDIDATES[*]}"
    exit 1
fi

echo "Detected: $DETECTED"
minipro -p "$DETECTED" -r verify.bin
hexdump -C verify.bin > verify.hex
echo "Read back saved to verify.bin and verify.hex"
