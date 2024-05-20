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