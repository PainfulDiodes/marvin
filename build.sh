sjasmplus --raw=bin --lst=lst *.asm
hexdump -v -e '8/1 "0x%02x, "' -e '"\n"' bin > hex