    INCLUDE "asm/system.inc"

    EXTERN MARVIN
    EXTERN PROMPT

    ORG MARVINORG
    ld sp, STACK
ALIGN 0x0010 ; fix the warmstart address across targets
WARMSTART:
    jp MARVIN
ALIGN 0x0010
WARMSTART2:
    jp PROMPT
