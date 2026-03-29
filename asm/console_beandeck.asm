    PUBLIC con_getchar

    EXTERN CONSOLE_STATUS, CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD
    PUBLIC con_readchar
    PUBLIC con_putchar
    PUBLIC con_puts

    EXTERN usb_readchar
    EXTERN usb_putchar
    EXTERN key_readchar
    EXTERN ra8875_console_putchar
    EXTERN ra8875_console_puts
    EXTERN ra8875_console_refresh_cursor
    EXTERN CAPS_LOCK_STATE, QWERTY_CAPS

; wait for a character and return in A
con_getchar:
    call con_readchar
    cp 0
    ret nz
    jr con_getchar

; read a character from the console and return in A - return 0 if there is no character
con_readchar:
    push hl
    ld hl,CONSOLE_STATUS
    ld a,CONSOLE_STATUS_BEANBOARD
    and (hl)
    jr nz,_readchar_keyboard
    ld a,CONSOLE_STATUS_USB
    and (hl)
    jr nz,_readchar_usb
    jr _readchar_end
_readchar_keyboard:
    call key_readchar
    cp QWERTY_CAPS
    jr nz,_readchar_end
    ; toggle caps lock state
    ld a,(CAPS_LOCK_STATE)
    xor 0x01
    ld (CAPS_LOCK_STATE),a
    ; redraw cursor to reflect new state
    call ra8875_console_refresh_cursor
    xor a               ; return 0 (consume keypress)
    jr _readchar_end
_readchar_usb:
    call usb_readchar
_readchar_end:
    pop hl
    ret

; send character in A to console
con_putchar:
    push bc
    push hl
    ld b,a
    ld hl,CONSOLE_STATUS
    ld a,CONSOLE_STATUS_BEANBOARD
    and (hl)
    jr nz,_putchar_ra8875
    ld a,CONSOLE_STATUS_USB
    and (hl)
    jr nz,_putchar_usb
    jr _putchar_done
_putchar_ra8875:
    ld a,b
    call ra8875_console_putchar
    jr _putchar_done
_putchar_usb:
    ld a,b
    call usb_putchar
_putchar_done:
    ld a,b
    pop hl
    pop bc
    ret

; print a zero-terminated string pointed to by hl to the console
con_puts:
    push hl
_puts_loop:
    ld a,(hl)
    cp 0
    jr z,_puts_end
    call con_putchar
    inc hl
    jp _puts_loop
_puts_end:
    pop hl
    ret
