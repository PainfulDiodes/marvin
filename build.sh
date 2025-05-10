# usage: 
# with or without extension
#  ./build.sh beanzee
#  ./build.sh beanzee.asm
# provide an org value (defaults to 0x0000)
#  ./build.sh beanzee $8000

# set -x #echo on

f=${1%.*} #extract base filename
if [ $# -gt 1 ]
then
    z88dk-z80asm -l -b -m -r$2 $f.asm
    hexdump -C $f.bin > $f.hex
    z88dk-appmake +hex --org $2 -b $f.bin -o $f.ihx
else
    z88dk-z80asm -l -b -m $f.asm
    hexdump -C $f.bin > $f.hex
    z88dk-appmake +hex -b $f.bin -o $f.ihx
fi