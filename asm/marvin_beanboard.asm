    INCLUDE "asm/system.inc"

    EXTERN MARVIN
    EXTERN PROMPT
    EXTERN lcd_init
    EXTERN beanboard_console_init

    ORG MARVINORG
    ld sp, STACK
    call lcd_init
    call beanboard_console_init
ALIGN 0x0010 ; fix the warmstart address across targets
WARMSTART:
    jp MARVIN
ALIGN 0x0010
WARMSTART2:
    jp PROMPT
