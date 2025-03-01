# usage: ./burn.sh myfile
#        ./burn.sh myfile.bin

# set -x      #echo on

f=${1%.*}   #extract base filename
minipro -u -s -p AT28C64B -w $f.bin
