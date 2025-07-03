# 1.2.1
  * Fix LCD scroll/render error - occasionally cursor would land on line 3 and the text would be out of step
  * LCD teletype style - always write on line 4 - would simplify the logic
  * Added a WARMSTART2 label - dependable entry point across builds - goes to MARVIN prompt without welcome message

# v1.2
* Remove beanboard_proto build target
* Remove keyscan_init so that on reset the last keypress is not repeated on RESET
  * On RESET (and x0) keyscan_init was run which cleared the buffer
  * This meant that any key still held down will register after RESET - meaning an extra keypress is sensed after reset
  * The solution is to simply not clear the buffer - under normal startup a change may be detected, but this will normally be "no keys" and so will have no effect
* Allow for multiple console devices
  * For the BeanZee target, console is fixed to USB
  * For the BeanBoard target, console may be either USB or keyboard/LCD - on RESET we sense for Beanboard shift key to determine which is the active console: shift-RESET=USB, RESET=beanboard
  * This also helps with speeding up loading programs via the USB: LCD echoing seems to significantly slow the USB transfer speed
* Renamed keyscan.asm > keymatrix.asm, keyscan > key_readchar (and associated labels)
* lcd_puts and usb_puts functions
* Build targets were previously kept in sync such that entry point addresses would work across all targets; now build targets (beanzee, beanboard) will not be consistent - beanboard code has been removed from from beanzee target and ALIGN padding between labels has been removed, with the exception of WARMSTART
* Added a WARMSTART label (with ALIGN padding) to fix a consistent warm-start address across all targets
* Revise build scripts to use an output directory (one directory for each supported assembler)
* Fixed Beanboard keyboard debounce delay

# v1.1.0
 
## Summary
Add support for BeanBoard  

## Tested On
* BeanZee v1
* BeanBoard prototype
* BeanBoard v1  

## What's Changed
* Add support for BeanBoard v1  
* Reorganised code: build targets in root, code modules in ASM directory  
* Updated build scripts to simplify multiple build targets and RAM options
  * RAM options are now entirele done with an ORG option on the command line
  * Hardware targets each have their own target asm file
* Source code set convention for 0x and 0b notation rather than $ and %, and prefixing underscores on local labels
* Made labels more specific - e.g. BUFFER => CMD_BUFFER
* Changed labels for escape characters to avoid starting with an underscore
* Changed comment format - avoid comments on same line as code
* Separate builds for BeanZee and BeanBoard, and RAM and ROM variants
* Separate string functions from marvin.asm into strings.asm, and make them safe to call:
  * hex_byte_val
  * hex_val
  * putchar_hex
* Drivers for BeanBoard LCD and keyboard; integrated these into getchar/putchar
* Message length by build target
* Keyboard map for beanboard v1

# v1.0.2
 
* Changed the handling of CR and LF to be consistent with VT100 terminals / typical defaults for terminal emulators:
  * Expect line termination of input with \r (\n is permitted, but \r\n will be interpreted as an extra empty line)
  * Transmit lines terminated with \r\n
* eXecute without an address will execute from 0x8000 (RAMSTART)
* Build scripts assume z88dk is used by default but sjasmplus is supported

# v1.0.1
Compatibility with z88dk-z80asm and sjasmplus.

# v1.0.0

## Summary
* Load command
* Case insensitive for hex values
* Tidy memory map

## Tested on
BeanZee v1

# v0.9.0
 
## Summary
x: eXecute command - enter an address to execute from

## Tested on
BeanZee v1

# v0.8.0

## Summary
w: write command - enter an address and string of hex data to memory

Whitespace on commands is now ignored, allowing for human-readable inputs

## Tested on
BeanZee v1

# v0.7.0
## Summary
* Completion of "r" command to support passing an address parameter, allow for empty commands, and support Escape key to abandon a command entry
* Passing an address argument to the r command
* Ignore \r in inputs
* Make puts function preserve registers
* Use zero string terminator in buffer rather than \n
* Empty command line is valid - does not generate error
* Escape key support

## Tested on
* BeanZee v1

# v0.6.0

## Summary
Refactor for Separation Of Concerns - separate out hardware concerns into:
* beanzee.asm - a top level file targetting beanzee/breadboard-computer
* UM245R.asm - console implementation for the UM245R used by beanzee/breadboard-computer

## Tested with:
* Z80 Breadboard Computer v1

# v0.5.0
* Fix to USB status bit tests.  
* Tested with: Z80 Breadboard Computer v1, BeanZee v1

# v0.4.0 Pre-release

# v0.3.0 Pre-release
 
* Using UM245R, the device isn't immediately ready to write, but we were not checking TXE (D1 at port 0), so added a ready check at the start of the program
* Added a welcome message

# v0.2.0 Pre-release
 
* The original version was needed to operate entirely within RAM which was first run using an Arduino Mega to provide RAM to the Z80
* This version was altered to run in ROM, separating stack and buffer into RAM
* The original version had an error in that it assumed the stack worked up from a given memory location
* This version understand that the stack works downward though memory and so starts at 0xffff
* Technically this should be 0x0000 as the first PUSH will decrement the SP to 0xffff

# v0.1.0 Pre-release

* This version was needs to operate entirely within RAM  
* It was first run using an Arduino Mega to provide RAM to the Z80  
