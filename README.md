# marvin - a tiny Z80 monitor program
Simple monitor program for my [z80-breadboard-computer](https://github.com/PainfulDiodes/z80-breadboard-computer) and the closely related [BeanZee](https://github.com/PainfulDiodes/BeanZee) Z80 development board.

## Assumptions and dependencies

Memory map:  
0000 - 7FFF : 32k ROM  
8000 - FFFF : 32k RAM  

Buffer starts at bottom of RAM (8000)  
Stack starts at top of RAM (FFFF) (working down)  

The program expects to find an [FTDI UM245R USB to Parallel FIFO Development Module](https://ftdichip.com/wp-content/uploads/2020/08/DS_UM245R.pdf) at ports 0 and 1:

Port 0 : status (read only)  
Port 1 : data (read / write)   

Status byte:  
Bit 0 : device ready for data to be written (active low)  
Bit 1 : data available in read buffer (active low)  

## Commands
Commands ignore whitespace.  
Backspace is not supported.  
Esc will abandon a command and return to the prompt.  
Hex input values are 0-9, a-f (upper case not recognised).  

### r: read
r alone will read from the current memory cursor position and print 16 bytes in hex format (the cursor defaults to 0x0000 on reset)  

r followed by an address as 4 hex digits will start reading from the provided address  

r followed by 2 hex digits will treat those digits as the upper byte of the address and effectively append 0x00 as the lower byte  

### w: write
w requires a 4 digit hex address followed by a stream of hex pairs representing consecutive data bytes

E.g.

    w 9000 3e 0a d3 01 3e

This command will write to memory as:

    Addr Value
    9000 3E
    9001 0A
    9002 d3
    9003 01
    9004 3E
    
### x: execute
x requires a 4 digit hex address, and will commence executing code at that address.
