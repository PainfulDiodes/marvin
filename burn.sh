# usage: ./burn.sh target

set -x #echo on

f=${1%.*} #extract base filename
minipro -u -s -p AT28C64B -w targets/$f/output/marvin_$f.bin
