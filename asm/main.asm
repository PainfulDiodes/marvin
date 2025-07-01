ORG MARVINORG
    ld sp, STACK
IF BEANBOARD
    call lcd_init
    call lcd_init_buffer
    call beanboard_console_init
    call _beanboard_console_init_usb ; temporary lock to USB - TODO remove this line
ENDIF
ALIGN 0x0010 ; fix the warmstart address across targets
WARMSTART:
    jp MARVIN
