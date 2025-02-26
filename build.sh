# usage: ./build.sh beanzee
#        ./build.sh beanzee.asm
set -x      #echo on
f=${1%.*}   #extract base filename
sjasmplus --lst=$f.lst --lstlab --raw=$f.bin --dirbol $f.asm
hexdump -C $f.bin > $f.hdp