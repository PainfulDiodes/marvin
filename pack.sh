# usage: ./pack.sh test1 0x9000 
#        ./pack.sh test1.bin 0x9000 
f=${1%.*}   #extract base filename
z88dk-appmake +hex --org $2 -b $f.bin -o $f.hex