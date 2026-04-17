; helpers.inc - shared helpers for Marvin ABI tests
; Included by beanzee.asm, beanboard.asm, beandeck.asm

; _usb_waitkey: blocking wait for a USB keypress
; out: A = char received
; destroys: AF
_usb_waitkey:
    call MARVIN_USB_READCHAR
    or a
    jr z, _usb_waitkey
    ret

; _usb_puthex: print A as two uppercase hex digits to USB
; in: A = byte to print
; destroys: AF
_usb_puthex:
    push af
    rrca
    rrca
    rrca
    rrca
    and 0x0F
    call _uphn
    pop af
    and 0x0F
    ; fall through to _uphn for low nibble
_uphn:
    cp 10
    jr c, _uphn_digit
    add a, 'A' - 10
    jr _uphn_write
_uphn_digit:
    add a, '0'
_uphn_write:
    call MARVIN_USB_PUTCHAR
    ret
