# usage: 
# with or without extension
#  ./build.sh beanzee
#  ./build.sh beanzee.asm
# provide an org value
#  ./build.sh beanzee $8000
# defaults to 0x0000

# set -x #echo on

org=0x0000
orgname=MARVINORG

f=${1%.*} #extract base filename

if [ $# -gt 1 ]
then
    z88dk-z80asm -l -b -m -D$orgname=$2 $f.asm -Ooutput
    hexdump -C output/$f.bin > output/$f.hex
    z88dk-appmake +hex --org $2 -b output/$f.bin -o output/$f.ihx
else
    z88dk-z80asm -l -b -m -D$orgname=$org $f.asm -Ooutput
    hexdump -C output/$f.bin > output/$f.hex
    z88dk-appmake +hex --org $org -b output/$f.bin -o output/$f.ihx
fi