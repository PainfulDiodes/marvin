    INCLUDE "asm/system.inc"
    INCLUDE "asm/drivers/ra8875.inc"

    PUBLIC getchar
    PUBLIC readchar
    PUBLIC putchar
    PUBLIC puts
    PUBLIC ra8875_console_init

    EXTERN usb_readchar
    EXTERN usb_putchar
    EXTERN key_readchar
    EXTERN ra8875_putchar
    EXTERN ra8875_cursor_x
    EXTERN ra8875_cursor_y
    EXTERN ra8875_write_reg
    EXTERN ra8875_read_reg

CURSOR_CHAR equ '_'

; Initialise RA8875 console state.
; Resets VOFS to 0, hides hardware cursor, zeroes tracking variables,
; draws the initial software cursor.
ra8875_console_init:
    ; reset scroll offset to zero
    ld a,RA8875_VOFS0
    ld b,0
    call ra8875_write_reg
    ld a,RA8875_VOFS1
    ld b,0
    call ra8875_write_reg
    ; hide hardware cursor - software cursor used instead
    ld a,RA8875_MWCR0
    call ra8875_read_reg
    and ~RA8875_MWCR0_CURSOR
    ld b,a
    ld a,RA8875_MWCR0
    call ra8875_write_reg
    ; zero-init cursor and scroll state
    xor a
    ld (RA8875_CURSOR_COL),a
    ld (RA8875_CURSOR_ROW),a
    ld (RA8875_SCROLL_TOP),a
    ; draw initial software cursor at (0,0)
    call _draw_cursor
    ret


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
    cp 0x0d                     ; carriage return?
    jr z,_putchar_newline
    ; character overwrites software cursor at current position; RA8875 auto-advances
    call ra8875_putchar
    ld hl,RA8875_CURSOR_COL
    inc (hl)
    ld a,(RA8875_CURSOR_COL)
    cp RA8875_COLS              ; reached end of line?
    jr z,_putchar_line_wrap
    call _draw_cursor
    jr _putchar_done
_putchar_line_wrap:
    ; implicit wrap: typed character already overwrote cursor, no erase needed
    xor a
    ld (RA8875_CURSOR_COL),a
    call _advance_line
    jr _putchar_done
_putchar_newline:
    ; erase software cursor with a space before moving to next line
    ld a,' '
    call ra8875_putchar
    xor a
    ld (RA8875_CURSOR_COL),a
    call _advance_line
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


; Advance cursor to the next row, scrolling if on the last visible row.
; Assumes RA8875_CURSOR_COL has already been reset to 0 by the caller.
; Draws the software cursor at the new position.
; Preserves all registers.
_advance_line:
    push af
    push bc
    push hl

    ; last_visible = (scroll_top + RA8875_ROWS - 1) % RA8875_ROWS
    ; This calculates which physical row is currently at the bottom of the display — 
    ; the last visible row.
    ; For example, with 30 rows and scroll_top = 5, the last visible row is physical row 4
    ; (wrapping around the circular buffer: rows 5, 6, … 29, 0, 1, 2, 3, 4).
    ; The % ROWS is done with a conditional subtract rather than a true modulo — 
    ; this works because scroll_top is always in range [0, ROWS-1], 
    ; so scroll_top + (ROWS-1) can overshoot by at most ROWS-1, 
    ; meaning a single subtract is sufficient to bring it back in range.
    ; After this block, A holds the physical row number of the last visible (bottom) line, 
    ; which is then compared against the current cursor row to decide whether a scroll is needed.
    ld a,(RA8875_SCROLL_TOP)
    add a,RA8875_ROWS-1
    cp RA8875_ROWS
    jr c,_al_no_wrap
    sub RA8875_ROWS
_al_no_wrap:
    ; A = last_visible physical row
    ld b,a
    ld a,(RA8875_CURSOR_ROW)
    cp b
    jr nz,_al_advance           ; not on last visible row: simple advance

    ; on last visible row: hardware scroll up one row
    ld a,(RA8875_SCROLL_TOP)
    ld c,a                      ; C = old scroll_top (becomes new cursor row)
    inc a
    cp RA8875_ROWS
    jr nz,_al_scroll_ok
    xor a
_al_scroll_ok:
    ld (RA8875_SCROLL_TOP),a    ; scroll_top = (old + 1) % RA8875_ROWS

    ; VOFS = scroll_top * 16 (fits in 9 bits, max 29*16=464)
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl                   ; HL = scroll_top * 16
    ld a,RA8875_VOFS0
    ld b,l
    call ra8875_write_reg
    ld a,RA8875_VOFS1
    ld b,h
    call ra8875_write_reg

    ; cursor goes to old scroll_top (now the new bottom row)
    ld a,c
    ld (RA8875_CURSOR_ROW),a
    call _cursor_xy_position    ; position RA8875 to col 0 of new bottom row

    ; clear the new bottom row
    ld b,RA8875_COLS
_al_clear_loop:
    ld a,' '
    call ra8875_putchar
    djnz _al_clear_loop

    call _draw_cursor
    jr _al_done

_al_advance:
    ; advance cursor_row by one (wraps mod RA8875_ROWS)
    ld a,(RA8875_CURSOR_ROW)
    inc a
    cp RA8875_ROWS
    jr nz,_al_set_row
    xor a
_al_set_row:
    ld (RA8875_CURSOR_ROW),a
    call _draw_cursor

_al_done:
    pop hl
    pop bc
    pop af
    ret


; Position RA8875 text cursor at (RA8875_CURSOR_COL * 8, RA8875_CURSOR_ROW * 16) pixels.
; Preserves all registers.
_cursor_xy_position:
    push af
    push hl
    ld a,(RA8875_CURSOR_COL)
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl                   ; HL = cursor_col * 8 (RA8875_CHAR_W)
    call ra8875_cursor_x
    ld a,(RA8875_CURSOR_ROW)
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl                   ; HL = cursor_row * 16 (RA8875_CHAR_H)
    call ra8875_cursor_y
    pop hl
    pop af
    ret


; Draw software cursor at current (RA8875_CURSOR_ROW, RA8875_CURSOR_COL).
; Positions RA8875 cursor, writes CURSOR_CHAR, then repositions (putchar advances cursor).
; Preserves all registers.
_draw_cursor:
    push af
    call _cursor_xy_position
    ld a,CURSOR_CHAR
    call ra8875_putchar
    call _cursor_xy_position    ; reposition: putchar advanced the RA8875 cursor
    pop af
    ret


; print a zero-terminated string pointed to by hl to the console
puts:
    push hl
_puts_loop:
    ld a,(hl)
    cp 0
    jr z,_puts_end
    call putchar
    inc hl
    jp _puts_loop
_puts_end:
    pop hl
    ret
