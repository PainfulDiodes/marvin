# usage: 
# with or without extension
#  ./build-sjasmplus.sh beanzee
#  ./buildsjasmplus.sh beanzee.asm
# provide an org value to pack a HEX file
#  ./build-sjasmplus.sh beanzee 0x8000

set -x      #echo on

f=${1%.*}   #extract base filename
sjasmplus --lst=$f.lst --lstlab --raw=$f.bin --dirbol $f.asm
hexdump -C $f.bin > $f.hdp
if [ $# -gt 1 ]
then
    z88dk-appmake +hex --org $2 -b $f.bin -o $f.hex
fi