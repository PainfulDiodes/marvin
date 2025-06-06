# usage: 
# with or without extension
#  ./build-sjasmplus.sh beanzee
#  ./buildsjasmplus.sh beanzee.asm
# provide an org value to pack a HEX file
#  ./build-sjasmplus.sh beanzee $8000

# set -x #echo on

f=${1%.*} #extract base filename
if [ $# -gt 1 ]
then
    sjasmplus --lst=$f.lis --lstlab --raw=$f.bin --dirbol --define ORGDEF=$2  $f.asm
    hexdump -C $f.bin > $f.hex
    z88dk-appmake +hex --org $2 -b $f.bin -o $f.ihx
else
    sjasmplus --lst=$f.lis --lstlab --raw=$f.bin --dirbol $f.asm
    hexdump -C $f.bin > $f.hex
    z88dk-appmake +hex -b $f.bin -o $f.ihx
fi