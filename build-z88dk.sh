# usage: 
# with or without extension
#  ./build-z88dk.sh beanzee
#  ./build-z88dk.sh beanzee.asm
# provide an org value to pack a HEX file
#  ./build-z88dk.sh beanzee 0x8000

set -x      #echo on

f=${1%.*}   #extract base filename
z88dk-z80asm -l -b $f.asm
hexdump -C $f.bin > $f.hdp
if [ $# -gt 1 ]
then
    z88dk-appmake +hex --org $2 -b $f.bin -o $f.hex
fi