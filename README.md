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
