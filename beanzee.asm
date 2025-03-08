; MARVIN build for beanzee / Z80 breadboard computer
; https://github.com/PainfulDiodes/BeanZee/tree/v1.0.0
; https://github.com/PainfulDiodes/z80-breadboard-computer/tree/v1.0.0

ORG 0x0000

BUFFER equ 0xf000          ; input buffer - start of system RAM
STACK  equ 0xffff          ; this should really be 0x0000 as the CPU will dec SP before PUSH

    ld sp, STACK
    jp start

include "UM245R.asm"
UM245R_CTRL equ 0          ; serial control port
UM245R_DATA equ 1          ; serial data port

include "marvin.asm"