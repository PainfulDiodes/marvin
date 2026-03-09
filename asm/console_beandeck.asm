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
    ; write B (char) to framebuffer[row][col]
    ; _fb_row_offsets is composed of 16-bit words, therefore in order to 
    ; access the desired word we need to double the index (row number)
    ld a,(RA8875_CURSOR_Y)
    add a,a                     ; A = row * 2 (word index into table)
    ld e,a
    ld d,0                      ; DE = row * 2
    ld hl,_fb_row_offsets
    add hl,de                   ; HL = &_fb_row_offsets[row]
    ld e,(hl)
    inc hl
    ld d,(hl)                   ; DE = row_offset (row * 100)
    ld hl,RA8875_FRAMEBUFFER
    add hl,de                   ; HL = &framebuffer[row * 100]
    ld a,(RA8875_CURSOR_X)
    ld e,a
    ld d,0
    add hl,de                   ; HL = &framebuffer[row * 100 + col]
    ld (hl),b                   ; store char (B preserved throughout)
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
    ld a,(RA8875_CURSOR_Y)
    add a,a                     ; A = row * 2
    ld e,a
    ld d,0
    ld hl,_fb_row_offsets
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)                   ; DE = row * 100
    ld hl,RA8875_FRAMEBUFFER
    add hl,de                   ; HL = row start in framebuffer
    ld a,(RA8875_CURSOR_X)
    ld e,a
    ld d,0
    add hl,de                   ; HL = current position in row
    ld a,RA8875_COLS
    sub e                       ; A = remaining columns
    jr z,_newline_pad_done
    ld b,a
_newline_pad_loop:
    ld (hl),' '
    inc hl
    djnz _newline_pad_loop
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
; When already at last row, scroll: shift framebuffer up, clear last row, redraw display.
; Preserves BC, DE, HL.
_advance_line:
    push bc
    push de
    push hl
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
    ; shift framebuffer up one row: rows 1-29 become rows 0-28
    ld hl,RA8875_FRAMEBUFFER + RA8875_COLS      ; src = row 1
    ld de,RA8875_FRAMEBUFFER                    ; dst = row 0
    ld bc,(RA8875_ROWS-1) * RA8875_COLS         ; 2900 bytes
    ldir

    ; clear last row in framebuffer with spaces
    ld hl,RA8875_FRAMEBUFFER + (RA8875_ROWS-1) * RA8875_COLS
    ld (hl),' '
    ld de,RA8875_FRAMEBUFFER + (RA8875_ROWS-1) * RA8875_COLS + 1
    ld bc,RA8875_COLS-1
    ldir

    ; redraw display: set cursor to (0,0), bulk-write all 3000 chars
    call ra8875_cursor_hide
    ld hl,0
    call ra8875_cursor_x
    call ra8875_cursor_y
    call ra8875_memory_read_write_command       ; issue MRWC once for bulk write
    ld hl,RA8875_FRAMEBUFFER
    ld bc,RA8875_ROWS * RA8875_COLS             ; 3000
_redraw_loop:
    ld a,(hl)
    call ra8875_write_data                      ; stream char without re-issuing command
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,_redraw_loop

    ; position cursor at start of last row
    ld hl,0
    call ra8875_cursor_x
    ld hl,RA8875_LAST_ROW_Y                     ; 464 = 29 * 16
    call ra8875_cursor_y
    ld (RA8875_CURSOR_Y_PIX),hl                     ; update RAM cursor Y
    call ra8875_cursor_show
    ; RA8875_CURSOR_Y stays 29, RA8875_CURSOR_X stays 0
    pop hl
    pop de
    pop bc
    ret

; framebuffer row offset table: row -> byte offset (row * 100)
; 30 entries * 2 bytes = 60 bytes
_fb_row_offsets:
    dw 0, 100, 200, 300, 400, 500, 600, 700, 800, 900
    dw 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900
    dw 2000, 2100, 2200, 2300, 2400, 2500, 2600, 2700, 2800, 2900

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
