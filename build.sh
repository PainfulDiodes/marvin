# usage: ./build.sh myfile.asm
set -x      #echo on
f=${1%.*}   #extract base filename
sjasmplus --lst=$f.lst --lstlab --raw=$f.bin --dirbol $1
hexdump -C $f.bin > $f.hex