#!/usr/bin/env bash

# Build Marvin firmware
# Usage: ./build.sh [target]
# Examples:
#   ./build.sh              # build all targets
#   ./build.sh beanzee      # build beanzee only
#
# Each target produces two builds:
#   marvin.bin     - combined firmware (Marvin + BBC BASIC)
#   marvin_minimal.bin - minimal firmware (Marvin monitor only)
#
# Requires: z88dk (z88dk-z80asm, z88dk-appmake)

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MARVIN_ASM="$REPO_DIR/asm"
DRIVER_DIR="$REPO_DIR/asm/drivers"
BASIC_SRC="$REPO_DIR/BBCZ80/src"
SHARED_DIR="$REPO_DIR/targets/shared"

CODE_ORG="0x0000"
DATA_ORG="0x8000"
OUTPUT_NAME="marvin"
MINIMAL_NAME="marvin_minimal"

BASIC_MODULES="EXEC EVAL ASMB MATH DATA"

# ---- Per-target module lists (combined firmware) ----

modules_for_target() {
    case $1 in
        beanzee)
            COMBINED_ENTRY="entry_beanzee"
            MARVIN_MODULES="console_beanzee monitor hex messages"
            DRIVER_MODULES="um245r"
            BASIC_MAIN="MAIN"
            ;;
        beanboard)
            COMBINED_ENTRY="entry_beanboard"
            MARVIN_MODULES="console_beanboard init_beanboard monitor hex messages_beanboard"
            DRIVER_MODULES="um245r hd44780 keymatrix"
            BASIC_MAIN="MAIN_SM_DSP"
            ;;
        beandeck)
            COMBINED_ENTRY="entry_beandeck"
            MARVIN_MODULES="console_beandeck init_beanboard monitor hex messages"
            DRIVER_MODULES="um245r keymatrix"
            BASIC_MAIN="MAIN"
            ;;
        *)
            echo "Error: unknown target '$1'"
            echo "Valid targets: beanzee, beanboard, beandeck"
            exit 1
            ;;
    esac
}

# ---- Per-target module lists (minimal firmware) ----
# Module order determines link order and ROM layout.
# Paths relative to asm/ directory (drivers use drivers/ prefix).

minimal_modules_for_target() {
    case $1 in
        beanzee)
            MINIMAL_ENTRY="entry_beanzee_minimal"
            MINIMAL_MODULES="console_beanzee drivers/um245r monitor hex messages"
            ;;
        beanboard)
            MINIMAL_ENTRY="entry_beanboard_minimal"
            MINIMAL_MODULES="console_beanboard init_beanboard drivers/um245r monitor hex drivers/hd44780 drivers/keymatrix messages_beanboard"
            ;;
        beandeck)
            MINIMAL_ENTRY="entry_beandeck_minimal"
            MINIMAL_MODULES="console_beandeck init_beanboard drivers/um245r monitor hex drivers/keymatrix messages"
            ;;
    esac
}

# ---- Build combined firmware (Marvin + BBC BASIC) ----

build_target() {
    local target=$1
    local TARGET_DIR="$REPO_DIR/targets/$target"
    local OUTDIR="$TARGET_DIR/output"

    modules_for_target "$target"

    echo "Building Marvin ($target)"
    echo "==========================="

    mkdir -p "$OUTDIR"
    rm -f "$OUTDIR"/*.o "$OUTDIR"/*.lis

    # ---- Boot module ----

    echo ""
    echo "Assembling boot module..."
    echo "  $COMBINED_ENTRY.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/$COMBINED_ENTRY.o" "$MARVIN_ASM/$COMBINED_ENTRY.asm"

    # ---- Marvin modules ----

    echo ""
    echo "Assembling Marvin modules..."
    for module in $MARVIN_MODULES; do
        echo "  $module.asm"
        z88dk-z80asm -l -m -DINCLUDE_BASIC -I"$REPO_DIR" -o"$OUTDIR/$module.o" "$MARVIN_ASM/$module.asm"
    done

    echo ""
    echo "Assembling driver modules..."
    for module in $DRIVER_MODULES; do
        echo "  $module.asm"
        z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/$module.o" "$DRIVER_DIR/$module.asm"
    done

    # ---- BBC BASIC core modules ----

    echo ""
    echo "Assembling BBC BASIC modules..."
    echo "  $BASIC_MAIN.asm"
    z88dk-z80asm -l -m -o"$OUTDIR/$BASIC_MAIN.o" "$BASIC_SRC/$BASIC_MAIN.asm"
    for module in $BASIC_MODULES; do
        EXTRA_FLAGS=""
        if [ "$module" = "DATA" ]; then
            EXTRA_FLAGS="-DDATA_ORG=$DATA_ORG"
        fi
        echo "  $module.asm"
        z88dk-z80asm -l -m $EXTRA_FLAGS -o"$OUTDIR/$module.o" "$BASIC_SRC/$module.asm"
    done

    echo "  BHOOK.asm"
    z88dk-z80asm -l -m -o"$OUTDIR/BHOOK.o" "$SHARED_DIR/BBCZ80/BHOOK.asm"

    echo "  BMOS.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/BMOS.o" "$SHARED_DIR/BBCZ80/BMOS.asm"

    # ---- Shared BBC BASIC entry point ----

    echo ""
    echo "Assembling BBC BASIC entry point..."
    echo "  ENTRY.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/ENTRY.o" "$SHARED_DIR/BBCZ80/ENTRY.asm"

    # ---- Link ----
    # Boot module must be first (contains ORG 0x0000 and jump table)

    ALL_OBJS="$OUTDIR/$COMBINED_ENTRY.o $OUTDIR/ENTRY.o"
    for module in $MARVIN_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$module.o"
    done
    for module in $DRIVER_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$module.o"
    done
    ALL_OBJS="$ALL_OBJS $OUTDIR/$BASIC_MAIN.o"
    for module in $BASIC_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$module.o"
    done
    ALL_OBJS="$ALL_OBJS $OUTDIR/BHOOK.o"
    ALL_OBJS="$ALL_OBJS $OUTDIR/BMOS.o"

    echo ""
    echo "Linking all modules at $CODE_ORG..."
    z88dk-z80asm -b -m \
        -o"$OUTDIR/$OUTPUT_NAME.bin" \
        -r$CODE_ORG \
        $ALL_OBJS

    # Remove DATA section binary - it lives in RAM, not ROM
    rm -f "$OUTDIR/${OUTPUT_NAME}_data.bin"

    BIN_SIZE=$(wc -c < "$OUTDIR/$OUTPUT_NAME.bin" | tr -d ' ')

    xxd "$OUTDIR/$OUTPUT_NAME.bin" > "$OUTDIR/$OUTPUT_NAME.hex"

    echo ""
    echo "Build complete:"
    echo "  ROM image: output/$OUTPUT_NAME.bin ($BIN_SIZE bytes at $CODE_ORG)"
    echo "  Hex dump:  output/$OUTPUT_NAME.hex"
    echo "  Map file:  output/$OUTPUT_NAME.map"
    echo ""
    echo "Memory layout:"
    echo "  ROM: $CODE_ORG - code ($BIN_SIZE bytes)"
    echo "  RAM: $DATA_ORG - data segment (initialised at runtime)"
}

# ---- Build minimal firmware (Marvin monitor only, no BBC BASIC) ----

build_minimal() {
    local target=$1
    local TARGET_DIR="$REPO_DIR/targets/$target"
    local OUTDIR="$TARGET_DIR/output"

    minimal_modules_for_target "$target"

    echo "Building Marvin minimal ($target)"
    echo "==========================="

    mkdir -p "$OUTDIR"

    # ---- Entry module ----

    echo ""
    echo "Assembling entry module..."
    echo "  $MINIMAL_ENTRY.asm"
    z88dk-z80asm -l -m -DMARVINORG=$CODE_ORG -I"$REPO_DIR" \
        -o"$OUTDIR/$MINIMAL_ENTRY.o" "$MARVIN_ASM/$MINIMAL_ENTRY.asm"

    # ---- Marvin and driver modules ----

    echo ""
    echo "Assembling modules..."
    for module in $MINIMAL_MODULES; do
        local obj_name=$(basename "$module")
        echo "  $module.asm"
        z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/$obj_name.o" "$MARVIN_ASM/$module.asm"
    done

    # ---- Link ----
    # Entry module must be first (contains ORG and jump table)

    ALL_OBJS="$OUTDIR/$MINIMAL_ENTRY.o"
    for module in $MINIMAL_MODULES; do
        local obj_name=$(basename "$module")
        ALL_OBJS="$ALL_OBJS $OUTDIR/$obj_name.o"
    done

    echo ""
    echo "Linking minimal modules at $CODE_ORG..."
    z88dk-z80asm -b -m \
        -o"$OUTDIR/$MINIMAL_NAME.bin" \
        -r$CODE_ORG \
        $ALL_OBJS

    BIN_SIZE=$(wc -c < "$OUTDIR/$MINIMAL_NAME.bin" | tr -d ' ')

    xxd "$OUTDIR/$MINIMAL_NAME.bin" > "$OUTDIR/$MINIMAL_NAME.hex"
    z88dk-appmake +hex --org $CODE_ORG \
        -b "$OUTDIR/$MINIMAL_NAME.bin" \
        -o "$OUTDIR/$MINIMAL_NAME.ihx"

    echo ""
    echo "Minimal build complete:"
    echo "  ROM image:   output/$MINIMAL_NAME.bin ($BIN_SIZE bytes at $CODE_ORG)"
    echo "  Hex dump:    output/$MINIMAL_NAME.hex"
    echo "  Intel HEX:   output/$MINIMAL_NAME.ihx"
    echo "  Map file:    output/$MINIMAL_NAME.map"
}

# ---- Main ----

# Check BBCZ80 submodule is initialised
if [ ! -f "$REPO_DIR/BBCZ80/build.sh" ]; then
    echo "Error: BBCZ80 submodule not initialised."
    echo "Run: git submodule update --init"
    exit 1
fi

# Convert BBC BASIC sources if not already done
if [ ! -f "$BASIC_SRC/MAIN.asm" ]; then
    echo "=== Converting BBC BASIC sources ==="
    cd "$REPO_DIR/BBCZ80"
    ./convert.sh
    cd "$REPO_DIR"
    echo ""
fi

if [ $# -gt 0 ]; then
    build_target "$1"
    echo ""
    build_minimal "$1"
else
    for target in beanzee beanboard beandeck; do
        build_target "$target"
        echo ""
        build_minimal "$target"
        echo ""
    done
fi
