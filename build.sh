# usage: 
# with or without extension
#  ./build.sh beanzee
#  ./build.sh beanzee.asm
# provide an org value
#  ./build.sh beanzee $8000
# defaults to 0x0000

# set -x #echo on

org=0x0000
f=${1%.*} #extract base filename

if [ $# -gt 1 ]
then
    z88dk-z80asm -l -b -m -DORGDEF=$2 $f.asm
    hexdump -C $f.bin > $f.hex
    z88dk-appmake +hex --org $2 -b $f.bin -o $f.ihx
else
    z88dk-z80asm -l -b -m $f.asm
    hexdump -C $f.bin > $f.hex
    z88dk-appmake +hex --org $org -b $f.bin -o $f.ihx
fi