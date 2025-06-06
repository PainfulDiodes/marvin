# usage: ./pack.sh test1 $9000 
#        ./pack.sh test1.bin $9000 
set -x #echo on
f=${1%.*} #extract base filename
z88dk-appmake +hex --org $2 -b $f.bin -o $f.ihx