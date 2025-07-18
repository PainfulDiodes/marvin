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

    sjasmplus  --nologo --msg=err --lst=output-sj/$f.lis --lstlab --raw=output-sj/$f.bin --dirbol --define MARVINORG=$org  $f.asm
    hexdump -C output-sj/$f.bin > output-sj/$f.hex
    z88dk-appmake +hex --org $org -b output-sj/$f.bin -o output-sj/$f.ihx

else  
    echo "Missing target"
fi
