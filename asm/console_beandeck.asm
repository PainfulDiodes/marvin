    INCLUDE "asm/system.inc"
    INCLUDE "asm/drivers/ra8875.inc"

RA8875_FRAMEBUFFER_END equ RA8875_FRAMEBUFFER + RA8875_ROWS * RA8875_COLS

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
    EXTERN ra8875_cursor_hide
    EXTERN ra8875_cursor_show
    EXTERN ra8875_memory_read_write_command
    EXTERN ra8875_write_data

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
    call ra8875_putchar         ; write char to display
    ; write B (char) to framebuffer via direct write pointer
    ld hl,(FB_WRITE_PTR)
    ld (hl),b                   ; store char
    inc hl
    ld (FB_WRITE_PTR),hl        ; advance pointer (no wrap check: rows never straddle buffer end)
    ; update X column counter
    ld a,(RA8875_CURSOR_X)
    inc a
    ld (RA8875_CURSOR_X),a
    cp RA8875_COLS
    jr nz,_putchar_done         ; not at end of line: done
    ; line wrap: reset X, advance Y
    xor a
    ld (RA8875_CURSOR_X),a
    call _advance_line
    jr _putchar_done
_putchar_newline:
    ; pad remaining columns in framebuffer row with spaces
    ld hl,RA8875_CURSOR_X
    ld a,RA8875_COLS
    sub (hl)                    ; A = remaining columns (100 - col)
    jr z,_newline_pad_done
    ld b,a
    ld hl,(FB_WRITE_PTR)        ; HL = current write position
_newline_pad_loop:
    ld (hl),' '
    inc hl
    djnz _newline_pad_loop
    ld (FB_WRITE_PTR),hl        ; HL now at next row start (wrap checked in _advance_line)
_newline_pad_done:
    ld b,0x0a                   ; restore B = newline char (djnz clobbered B)
    ; reset X and set hardware cursor X to 0
    xor a
    ld (RA8875_CURSOR_X),a
    call ra8875_cursor_hide
    ld hl,0
    call ra8875_cursor_x
    call _advance_line
    call ra8875_cursor_show
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

; advance RA8875_CURSOR_Y and RA8875_CURSOR_Y_PIX by one row.
; When already at last row, scroll: advance FB_SCREEN_START (circular), clear new last row, redraw display.
; Preserves BC, DE, HL.
_advance_line:
    push bc
    push de
    push hl
    ; check and apply circular buffer wrap (FB_WRITE_PTR wraps only at row boundaries)
    ld hl,(FB_WRITE_PTR)
    ld a,h
    cp RA8875_FRAMEBUFFER_END >> 8
    jr nz,_advance_no_wrap
    ld a,l
    cp RA8875_FRAMEBUFFER_END & 0xff
    jr nz,_advance_no_wrap
    ld hl,RA8875_FRAMEBUFFER    ; wrap to buffer start
    ld (FB_WRITE_PTR),hl
_advance_no_wrap:
    ld a,(RA8875_CURSOR_Y)
    cp RA8875_ROWS-1            ; already at last row?
    jr z,_scroll       ; yes: scroll
    inc a
    ld (RA8875_CURSOR_Y),a
    ld hl,(RA8875_CURSOR_Y_PIX)
    ld de,RA8875_CHAR_H
    add hl,de
    ld (RA8875_CURSOR_Y_PIX),hl
    call ra8875_cursor_y
    pop hl
    pop de
    pop bc
    ret

_scroll:
    ; advance FB_SCREEN_START by one row (circular): logical row 0 moves forward
    ld hl,(FB_SCREEN_START)
    ld de,RA8875_COLS           ; 100
    add hl,de
    ; wrap check: HL == 0xfcb8 (past end of physical buffer)?
    ld a,h
    cp RA8875_FRAMEBUFFER_END >> 8
    jr nz,_scroll_no_wrap
    ld a,l
    cp RA8875_FRAMEBUFFER_END & 0xff
    jr nz,_scroll_no_wrap
    ld hl,RA8875_FRAMEBUFFER    ; wrap to physical start
_scroll_no_wrap:
    ld (FB_SCREEN_START),hl

    ; clear new last row: FB_WRITE_PTR points to it (invariant: FB_WRITE_PTR == old FB_SCREEN_START)
    ld hl,(FB_WRITE_PTR)
    ld (hl),' '
    ld d,h
    ld e,l
    inc de
    ld bc,RA8875_COLS-1
    ldir

    ; redraw display: set cursor to (0,0), bulk-write all 3000 chars in two segments
    call ra8875_cursor_hide
    ld hl,0
    call ra8875_cursor_x
    call ra8875_cursor_y
    call ra8875_memory_read_write_command       ; issue MRWC once for bulk write

    ; segment 1: FB_SCREEN_START to end of physical buffer
    ld de,(FB_SCREEN_START)
    ld hl,RA8875_FRAMEBUFFER_END
    ld a,l
    sub e
    ld c,a
    ld a,h
    sbc a,d                     ; BC = 0xfcb8 - FB_SCREEN_START
    ld b,a
    ld hl,(FB_SCREEN_START)
    call _redraw_stream

    ; segment 2: physical buffer start to FB_SCREEN_START (zero bytes when no wrap yet)
    ld hl,(FB_SCREEN_START)
    ld de,RA8875_FRAMEBUFFER
    ld a,l
    sub e
    ld c,a
    ld a,h
    sbc a,d                     ; BC = FB_SCREEN_START - RA8875_FRAMEBUFFER
    ld b,a
    ld a,b
    or c
    jr z,_redraw_done
    ld hl,RA8875_FRAMEBUFFER
    call _redraw_stream
_redraw_done:

    ; position cursor at start of last row
    ld hl,0
    call ra8875_cursor_x
    ld hl,RA8875_LAST_ROW_Y                     ; 464 = 29 * 16
    call ra8875_cursor_y
    ld (RA8875_CURSOR_Y_PIX),hl                 ; update RAM cursor Y
    call ra8875_cursor_show
    ; RA8875_CURSOR_Y stays 29, RA8875_CURSOR_X stays 0
    pop hl
    pop de
    pop bc
    ret

; stream BC chars from (HL) to RA8875 (MRWC must already be issued)
_redraw_stream:
    ld a,b
    or c
    ret z                       ; do nothing if BC=0
_redraw_stream_loop:
    ld a,(hl)
    call ra8875_write_data
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,_redraw_stream_loop
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
