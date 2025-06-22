IFDEF ORGDEF
    ORG ORGDEF
ELSE
    ORG 0x0000
ENDIF

    ld sp, STACK
    call console_init
IF BEANBOARD
    call lcd_init
ENDIF
    jp START
