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
    call key_readchar
    jr _readchar_end
_readchar_usb:
    call usb_readchar
_readchar_end:
    pop hl
    ret

ALIGN 0x10

; sent character in A to the console 
putchar:
    push hl
    push bc
    ld b,a
    ld hl,CONSOLE_STATUS
    ld a,CONSOLE_STATUS_BEANBOARD
    and (hl)
    jr nz,_putchar_beanboard
    ld a,CONSOLE_STATUS_USB
    and (hl)
    jr nz,_putchar_usb
    jr _putchar_end
_putchar_beanboard:
    ld a,b
    call lcd_putchar
    jr _putchar_end
_putchar_usb:
    ld a,b
    call usb_putchar
_putchar_end:
    ld a,b
    pop bc
    pop hl
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

ALIGN 0x10

; BeanZee console init - USB is the active console
console_init:
    ld a,CONSOLE_STATUS_USB
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret

ALIGN 0x10

; determine which console should be active - Reset=beanboard, shift-Reset=USB
beanboard_console_init:
    ; check for modifier keys being held down
    call modifierkeys
    ; shift key down?
    and MOD_KEY_SHIFT
    ; yes shift
    jp nz,_beanboard_console_init_usb
    ; no shift
    ld a,CONSOLE_STATUS_BEANBOARD
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
_beanboard_console_init_usb:
    ld a,CONSOLE_STATUS_USB
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
