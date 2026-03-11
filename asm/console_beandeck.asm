    INCLUDE "asm/system.inc"
    INCLUDE "asm/drivers/ra8875.inc"

    PUBLIC getchar
    PUBLIC readchar
    PUBLIC putchar
    PUBLIC puts

    EXTERN usb_readchar
    EXTERN usb_putchar
    EXTERN key_readchar
    EXTERN ra8875_putchar
    EXTERN ra8875_cursor_x
    EXTERN ra8875_cursor_y
    EXTERN ra8875_write_reg

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

; send character in A to console
putchar:
    push bc
    push de
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
    cp 0x0a                     ; newline?
    jr z,_putchar_newline
    call ra8875_putchar
    ; track column and detect hardware line wrap
    ld a,(RA8875_CURSOR_X)
    inc a
    ld (RA8875_CURSOR_X),a
    cp RA8875_COLS              ; reached end of line (100)?
    jr nz,_putchar_done
    ; line wrapped: reset column counter and advance Y
    xor a
    ld (RA8875_CURSOR_X),a
    call _advance_line
    jr _putchar_done
_putchar_newline:
    xor a
    ld (RA8875_CURSOR_X),a      ; reset column counter
    ld hl,0
    call ra8875_cursor_x        ; reset hardware X to 0
    call _advance_line ; advance Y, scroll if needed
    jr _putchar_done
_putchar_usb:
    ld a,b
    call usb_putchar
_putchar_done:
    ld a,b
    pop hl
    pop de
    pop bc
    ret

; Advance the cursor to the next character row.
; Scrolls the display up by one line if the cursor is at the bottom.
; Preserves all registers.
_advance_line:
    push af
    push bc
    push de
    push hl

    ; compute new Y = RA8875_CURSOR_Y + 16
    ld hl,(RA8875_CURSOR_Y)
    ld de,RA8875_CHAR_H
    add hl,de                   ; HL = new Y

    ; check case 1: new_Y >= 480 (framebuffer wraps, always scroll)
    ld de,RA8875_SCREEN_H       ; 480
    or a                        ; clear carry
    sbc hl,de                   ; HL = new_Y - 480
    jr nc,_scroll_wrap          ; no carry: new_Y >= 480, HL = wrapped Y

    ; restore new_Y (carry set: HL underflowed)
    add hl,de                   ; HL = new_Y

    ; check case 2: screen full (SCROLL_Y > 0, always scroll)
    ld de,(RA8875_SCROLL_Y)
    ld a,d
    or e
    jr nz,_scroll_no_wrap       ; SCROLL_Y > 0: scroll without framebuffer wrap

    ; case 3: no scroll needed (screen not yet full)
    ld (RA8875_CURSOR_Y),hl
    jr _advance_done

_scroll_wrap:
    ; HL = new_Y - 480 (wrapped framebuffer position)
    ld (RA8875_CURSOR_Y),hl
    jr _do_scroll

_scroll_no_wrap:
    ; HL = new_Y (< 480, no framebuffer wrap)
    ld (RA8875_CURSOR_Y),hl

_do_scroll:
    ; update SCROLL_Y += 16, wrap at 480
    ld hl,(RA8875_SCROLL_Y)
    ld de,RA8875_CHAR_H
    add hl,de                   ; HL = SCROLL_Y + 16
    ld de,RA8875_SCREEN_H
    or a
    sbc hl,de                   ; HL = (SCROLL_Y+16) - 480
    jr nc,_scroll_store         ; no carry: was >= 480, already subtracted correctly
    add hl,de                   ; carry: was < 480, add 480 back to restore
_scroll_store:
    ld (RA8875_SCROLL_Y),hl

    ; write VOFS registers (HL = new SCROLL_Y)
    ld a,RA8875_VOFS0
    ld b,l
    call ra8875_write_reg
    ld a,RA8875_VOFS1
    ld b,h
    call ra8875_write_reg

    ; position hardware cursor at new (wrapped) line for clearing
    ld hl,(RA8875_CURSOR_Y)
    call ra8875_cursor_y
    ld hl,0
    call ra8875_cursor_x

    ; clear the new bottom line by overwriting with spaces
    ; ra8875_putchar preserves A and B via internal push/pop
    ld b,RA8875_COLS
    ld a,' '
_advance_clear_loop:
    call ra8875_putchar
    djnz _advance_clear_loop

    jr _advance_done

_advance_done:
    ; set hardware cursor to start of new line
    ld hl,(RA8875_CURSOR_Y)
    call ra8875_cursor_y
    ld hl,0
    call ra8875_cursor_x

    pop hl
    pop de
    pop bc
    pop af
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
