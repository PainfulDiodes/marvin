    INCLUDE "asm/system.inc"

    PUBLIC getchar
    PUBLIC readchar
    PUBLIC putchar
    PUBLIC puts

    EXTERN usb_readchar
    EXTERN usb_putchar
    EXTERN key_readchar

; wait for a character and return in A
getchar:
    call readchar
    cp 0
    ret nz
    jr getchar

; read a character from the console and return in A - return 0 if there is no character
readchar:
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
    jr _readchar_end
_readchar_usb:
    call usb_readchar
_readchar_end:
    pop hl
    ret

; send character in A to USB console
putchar:
    push bc
    ld b,a
    call usb_putchar
    ld a,b
    pop bc
    ret

; print a zero-terminated string pointed to by hl to the console
puts:
    push hl
_puts_loop:
    ; get character from string
    ld a,(hl)
    ; is it zero?
    cp 0
    ; yes
    jr z, _puts_end
    ; no: send character
    call putchar
    ; next character position
    inc hl
    ; loop for next character
    jp _puts_loop
_puts_end:
    pop hl
    ret
