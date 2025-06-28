IFDEF ORGDEF
    ORG ORGDEF
ELSE
    ORG 0x0000
ENDIF
    ld sp, STACK
IF BEANBOARD
    call lcd_init
    call beanboard_console_init
ENDIF
ALIGN 0x0010 ; fix the warmstart address across targets
WARMSTART:
    jp MARVIN
