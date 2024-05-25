# marvin - a tiny Z80 monitor program
The original version was needed to operate entirely within RAM   
which was first run using an Arduino Mega to provide RAM to the Z80

Altered to run in ROM, separating stack and buffer into RAM

The original version had an error in that it assumed the stack worked up from a given memory location

Altered to allow that the stack works downward though memory and so starts at 0xffff
Technically this can be 0x0000 as the first PUSH will decrement the SP to 0xffff 

Using UM245R, the device isn't immediately ready to write, but we're not checking TXE (D1 at port 0)
Added a ready check at the start of the program

Added a welcome message

## Assumptions

Memory map:
0000 - 1FFF : 8k ROM
2000 - 7FFF : EMPTY
8000 - FFFF : 32k RAM

Ports:
00 : Serial I/O status (read only)
01 : Serial I/O data (read / write)

Serial I/O status bits:
0 : data available in read buffer when high
1 : device ready for data to be written when high