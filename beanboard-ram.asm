; MARVIN build for BeanZee with BeanBoard - RAM version
; https://github.com/PainfulDiodes/BeanZee
; https://github.com/PainfulDiodes/BeanBoard

ORG 0x8000

RAMSTART equ 0x9000        ; start of user RAM
KEYSCAN_BUFFER equ $f000   ; 8-byte keyscan buffer

; TODO rename
BUFFER   equ 0xf010        ; input buffer - start of system RAM 

STACK    equ 0xffff        ; this should really be 0x0000 as the CPU will dec SP before PUSH

UM245R_CTRL equ 0               ; serial control port
UM245R_DATA equ 1               ; serial data port
KEYSCAN_OUT equ 2               ; either 2 or 3 will work
KEYSCAN_IN  equ 3               ; either 2 or 3 will work
LCD_CTRL    equ 4               ; LCD control port
LCD_DATA    equ 5               ; LCD data port

    ld sp, STACK
    call lcd_init
    call keyscan_init
    jp start

include "UM245R.asm"
include "marvin.asm"
include "HD44780LCD.inc"
include "HD44780LCD.asm"
include "keyscan.asm"