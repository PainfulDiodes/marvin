ALIGN $10

getchar:                    ; get character and return in A

    call keyscan
    cp 0
    ret nz

    call usb_read_char
    cp 0
    ret nz

    jr getchar

ALIGN $10

putchar:

    ; TODO push/pop needed? move them?
    push af
    call lcd_putchar
    pop af

    call usb_putchar
    ret

ALIGN $10

puts:                       ; print a zero-terminated string, pointed to by hl
    push hl
_puts_loop:
    ld a,(hl)               ; get character from string
    cp 0                    ; is it zero?
    jr z, _puts_end          ; yes - return
    call putchar            ; no - send character
    inc hl                  ; next character position
    jp _puts_loop            ; loop for next character
_puts_end:
    pop hl
    ret