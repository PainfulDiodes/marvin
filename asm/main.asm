IFDEF ORGDEF
    ORG ORGDEF
ELSE
    ORG 0x0000
ENDIF

    ld sp, STACK
IF BEANBOARD
    call lcd_init
    call keyscan_init
ENDIF
    jp START
