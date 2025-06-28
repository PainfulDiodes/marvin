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
    sjasmplus --lst=output-sj/$f.lis --lstlab --raw=output-sj/$f.bin --dirbol --define ORGDEF=$2  $f.asm
    hexdump -C output-sj/$f.bin > output-sj/$f.hex
    z88dk-appmake +hex --org $2 -b output-sj/$f.bin -o output-sj/$f.ihx
else
    sjasmplus --lst=output-sj/$f.lis --lstlab --raw=output-sj/$f.bin --dirbol --define ORGDEF=0x0000 $f.asm
    hexdump -C output-sj/$f.bin > output-sj/$f.hex
    z88dk-appmake +hex -b output-sj/$f.bin -o output-sj/$f.ihx
fi