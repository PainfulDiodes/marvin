; MARVIN build for BeanZee with BeanBoard - RAM version
; https://github.com/PainfulDiodes/BeanZee
; https://github.com/PainfulDiodes/BeanBoard

ORG 0x8000

RAMSTART equ 0x9000        ; start of user RAM
BUFFER   equ 0xf000        ; input buffer - start of system RAM
STACK    equ 0xffff        ; this should really be 0x0000 as the CPU will dec SP before PUSH

    ld sp, STACK
    jp start

include "UM245R.asm"
UM245R_CTRL equ 0          ; serial control port
UM245R_DATA equ 1          ; serial data port

include "marvin.asm"