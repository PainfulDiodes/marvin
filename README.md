# marvin - a tiny Z80 monitor program
The original version of this program needed to operate entirely within RAM which was first run using an Arduino Mega to provide RAM to the Z80. It also incorrectly assumed the stack worked up from a given memory location. The program was altered to run in ROM, separating stack and buffer into RAM, and allowed for the stack working downward though memory and so starts at 0xffff.
Technically this could be 0x0000 as the first PUSH will decrement the SP to 0xffff, but this may be less intuitive when reviewing the code.

## Assumptions

Memory map:
0000 - 1FFF : 8k ROM
2000 - 7FFF : EMPTY
8000 - FFFF : 32k RAM

The program assumes use of an UM245R where:

Ports:
00 : Serial I/O status (read only)
01 : Serial I/O data (read / write)

Serial I/O status bits:
0 : data available in read buffer when high
1 : device ready for data to be written when high