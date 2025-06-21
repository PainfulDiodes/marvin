ALIGN 0x10

; wait for a character and return in A
getchar:
    call readchar
    cp 0
    ret nz
    jr getchar 

ALIGN 0x10

; read a character from the console and return in A - return 0 if there is no character
readchar:
    push hl
    ld hl,CONSOLE_STATUS
    ld a,CONSOLE_STATUS_BEANBOARD
    and (hl)
    jr nz,_readchar_beanboard
    ld a,CONSOLE_STATUS_USB
    and (hl)
    jr nz,_readchar_usb
    jr _readchar_end
_readchar_beanboard:
    call keyscan
    jr _readchar_end
_readchar_usb:
    call usb_readchar
_readchar_end:
    pop hl
    ret

ALIGN 0x10

; sent character in A to the console 
putchar:
    push af
    call lcd_putchar
    pop af
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

console_init:
    ; check for keypress
    ; check usb
    call usb_readchar
    ; is there a character? 
    cp 0
    ; yes
    jr nz,_console_init_usb
    ; no: 
    ; check keyboard
    call keyscan
    ; is there a character? 
    cp 0
    ; yes
    jr nz,_console_init_beanboard
    ; no: loop again
    jr console_init
_console_init_beanboard:
    ld a,CONSOLE_STATUS_BEANBOARD
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
_console_init_usb:
    ld a,CONSOLE_STATUS_USB
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
