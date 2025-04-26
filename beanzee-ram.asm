; MARVIN build for beanzee / Z80 breadboard computer - RAM version
; https://github.com/PainfulDiodes/BeanZee
; https://github.com/PainfulDiodes/z80-breadboard-computer

ORG $8000

; start of user RAM
RAMSTART equ $9000
; input buffer - start of system RAM
CMD_BUFFER   equ $f000
; stack should really be $0000 as the CPU will dec SP before PUSH
STACK    equ $ffff

    ld sp, STACK
    jp start

include "UM245R.asm"
UM245R_CTRL equ 0 ; serial control port
UM245R_DATA equ 1 ; serial data port

include "marvin.asm"