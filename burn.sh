#!/usr/bin/env bash

# Burn a Marvin target binary to the EEPROM in the programmer.
# Auto-detects whether an AT28C256 or AT28C64B is present.
#
# Usage: ./burn.sh [target]
# Examples:
#   ./burn.sh              # burn beanzee (default)
#   ./burn.sh beanzee      # burn beanzee
#   ./burn.sh beanboard    # burn beanboard

set -e

TARGET="${1:-beanzee}"
BINARY="targets/$TARGET/output/marvin_$TARGET.bin"
CANDIDATES=("AT28C256" "AT28C64B")

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found: $BINARY"
    echo "Have you run ./build.sh $TARGET?"
    exit 1
fi

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
echo "Burning: $BINARY"
minipro -u -s -p "$DETECTED" -w "$BINARY"
