ALIGN 0x10

; wait for a character and return in A
getchar:
    call readchar
    cp 0
    ret nz
    jr getchar 

ALIGN 0x10

; read a character from the console and return it, 
; or 0 if there is no character
readchar:
IF BEANBOARD
    ; check keyboard
    call keyscan
    ; is there a character? 
    cp 0
    ; yes: return it
    ret nz
    ; no: 
ENDIF
    ; check usb
    call usb_readchar
    ; return the result - 0 if no char
    ret

ALIGN 0x10

; sent character in A to the console 
putchar:
IF BEANBOARD
    ; A is not guaranteed to be preserved in these calls, 
    ; so preserve across the first call
    push af
    call lcd_putchar
    pop af
ENDIF
    call usb_putchar
    ret

ALIGN 0x10

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