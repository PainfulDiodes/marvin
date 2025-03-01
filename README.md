# marvin - a tiny Z80 monitor program
A simple monitor program for the [BeanZee](https://github.com/PainfulDiodes/BeanZee) Z80 development board. Also works with [z80-breadboard-computer](https://github.com/PainfulDiodes/z80-breadboard-computer).

Builds with:  
[sjasmplus](https://github.com/z00m128/sjasmplus)  
[z88dk-z80asm](https://github.com/z88dk/z88dk/wiki/Tool---z80asm)  

## Assumptions and dependencies

Memory map:  
0000 - 7FFF : 32k ROM  
8000 - FFFF : 32k RAM  

Stack starts at top of RAM (FFFF) (working down)  
Buffer starts at bottom of system RAM (F000) 

8000-EFFF is available for user progams.

The program expects to find an [FTDI UM245R USB to Parallel FIFO Development Module](https://ftdichip.com/wp-content/uploads/2020/08/DS_UM245R.pdf) at ports 0 and 1:

Port 0 : status (read only)  
Port 1 : data (read / write)   

Status byte:  
Bit 0 : device ready for data to be written (active low)  
Bit 1 : data available in read buffer (active low)  

## Commands
General syntax / usage:
* Commands ignore whitespace
* Backspace is not supported
* Esc will abandon a command and return to the prompt
* Hex input values can use upper or lower case

### r - Read
r alone will read from the current memory cursor position and print 16 bytes in hex format (the cursor defaults to 0x0000 on reset)  

    >r
    0000: 31 ff ff c3 2a 00 db 00 cb 4f 20 fa db 01 c9 c5 
    >r
    0010: 47 db 00 cb 47 20 fa 78 d3 01 c1 c9 e5 7e fe 00 
    >r
    0020: 28 06 d3 01 23 c3 1d 00 e1 c9 11 00 00 21 77 01 
    >

r followed by an address as 4 hex digits will start reading from the provided address  

    >r001a
    001a: c1 c9 e5 7e fe 00 28 06 d3 01 23 c3 1d 00 e1 c9 
    >r
    002a: 11 00 00 21 77 01 cd 1c 00 21 00 80 3e 3e cd 0f 
    >

r followed by 2 hex digits will treat those digits as the upper byte of the address  

    >r02
    0200: 64 0a 00 4e 6f 20 64 61 74 61 20 74 6f 20 77 72 
    >

### w - Write
w requires a 4 digit hex address followed by a stream of hex pairs representing consecutive data bytes

    w 9000 3e 0a d3 01 3e

This command will write to memory as:

    Addr Value
    9000 3E
    9001 0A
    9002 d3
    9003 01
    9004 3E
    
### x - eXecute
x requires a 4 digit hex address, and will commence executing code at that address.

    >r9000
    9000: 3e 0a d3 01 3e 48 d3 01 3e 65 d3 01 3e 6c d3 01 
    >x9000

    Hello!

### : - load
This command takes an [Intel HEX](https://en.wikipedia.org/wiki/Intel_HEX) formatted line as a means to load assembled programs into memory. These can be entered by hand, but usually a "send file" function on your terminal emulator will be used to transmit a program.

    >MARVIN
    A super simple monitor program for Z80 homebrew
    (c) Stephen Willcock 2024
    https://github.com/PainfulDiodes

    >:109000003E0AD3013E48D3013E65D3013E6CD301F5
    >:109010003E6CD3013E6FD3013E21D3013E0AD30102
    >:05902000D301C30000B4
    >:00000001FF
    >x 9000

    Hello!

I have been using [z88dk](https://github.com/z88dk/z88dk)-appmake to pack Intel HEX files from binaries assembled using sjasmplus.

A couple of test examples are included in the repo - see the release binaries for the assembled files.