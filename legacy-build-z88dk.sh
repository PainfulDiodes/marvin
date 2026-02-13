#!/usr/bin/env bash

# usage: 
# with or without extension
#  ./build.sh beanzee
#  ./build.sh beanzee.asm
# provide an org value
#  ./build.sh beanzee $8000
# defaults to 0x0000

# set -x #echo on

if [ $# -gt 0 ]
then

    f=${1%.*} # extract target base name

    if [ $# -gt 1 ]
    then
        org=$2
    else
        org=0x0000
    fi

    z88dk-z80asm -l -b -m -DMARVINORG=$org $f.asm -Ooutput
    hexdump -C output/$f.bin > output/$f.hex
    z88dk-appmake +hex --org $org -b output/$f.bin -o output/$f.ihx

else  
    echo "Missing target"
fi
