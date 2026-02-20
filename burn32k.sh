# usage: ./burn32k.sh [-m] target
# -m : burn minimal build (marvin monitor only, no BBC BASIC)

set -x #echo on

minimal=false
while getopts "m" opt; do
    case $opt in
        m) minimal=true ;;
    esac
done
shift $((OPTIND - 1))

f=${1%.*} #extract base filename

if [ "$minimal" = true ]; then
    minipro -u -s -p AT28C256 -w targets/$f/output/marvin_minimal.bin
else
    minipro -u -s -p AT28C256 -w targets/$f/output/marvin.bin
fi
