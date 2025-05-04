; MARVIN build for beanzee / Z80 breadboard computer - RAM version
; https://github.com/PainfulDiodes/BeanZee

BEANBOARD EQU 0

ORG 0x8000

; start of user RAM
RAMSTART equ 0x9000
; input buffer - start of system RAM 
CMD_BUFFER equ 0xf010
; this should really be 0x0000 as the CPU will dec SP before PUSH
STACK equ 0xffff

UM245R_CTRL equ 0 ; serial control port
UM245R_DATA equ 1 ; serial data port
KEYSCAN_OUT equ 2 ; either 2 or 3 will work
KEYSCAN_IN  equ 3 ; either 2 or 3 will work
LCD_CTRL    equ 4 ; LCD control port
LCD_DATA    equ 5 ; LCD data port

    ld sp, STACK
    jp start

include "escapestring.inc"
include "console.asm"
include "UM245R.asm"
include "marvin.asm"
include "strings.asm"



