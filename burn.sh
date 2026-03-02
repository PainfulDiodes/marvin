# Burn EEPROM using David Griffiths minipro - for AT28C256 and AT28C64B devices
# usage: ./burn.sh [-m] [-8] target
# -m : burn minimal build (marvin monitor only, no BBC BASIC)
# -8 : use 8k EEPROM (AT28C64B) instead of 32k (AT28C256)

set -x #echo on

minimal=false
device=AT28C256
while getopts "m8" opt; do
    case $opt in
        m) minimal=true ;;
        8) device=AT28C64B ;;
    esac
done
shift $((OPTIND - 1))

f=${1%.*} #extract base filename

if [ "$minimal" = true ]; then
    minipro -u -s -p $device -w targets/$f/output/marvin_minimal.bin
else
    minipro -u -s -p $device -w targets/$f/output/marvin.bin
fi
