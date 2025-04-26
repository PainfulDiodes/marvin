LCD_COMMAND_0 equ LCD_FUNCTION_SET+LCD_DATA_LEN_8+LCD_DISP_LINES_2+LCD_FONT_8
LCD_COMMAND_1 equ LCD_DISPLAY_ON_OFF_CONTROL+LCD_DISPLAY_ON+LCD_CURSOR_ON+LCD_BLINK_ON

lcd_init:
; preserve registers
    push af
; intitialise device
	ld a,LCD_COMMAND_0
	call lcd_putcmd
	ld a,LCD_COMMAND_1
	call lcd_putcmd
	ld a,LCD_CLEAR_DISPLAY
	call lcd_putcmd
    ld a,0
    call lcd_putchar
; restore registers
    pop af
    ret

; transmit character in A to the control port
lcd_putcmd:                     
    push bc
; save the transmit character
    ld b,a
_lcd_putcmd_loop: 
; get the LCD status
    in a,(LCD_CTRL)
; busy ?
    bit 7,a
; yes
    jr nz,_lcd_putcmd_loop
; no, restore the transmit character
    ld a,b
; transmit the character
    out (LCD_CTRL),a
    pop bc
    ret

; get character from data port and return in A
lcd_getchar:                     
; get the LCD status
    in a,(LCD_CTRL)
; busy ?
    bit 7,a
; yes
    jr nz,lcd_getchar
; no, get a character
    in a,(LCD_DATA)
    ret

; transmit character in A to the data port
lcd_putchar:
    ; newline char?
    cp '\n'
    jp nz,_lcd_putchar_printable
    ; newline - fill out the line until EOL
_lcd_putchar_pad:
    ld a,' '
    call lcd_putdata
    cp LCD_EOL_0                
    jp z,_lcd_putchar_eol0
    cp LCD_EOL_1                
    jp z,_lcd_putchar_eol1
    cp LCD_EOL_2                
    jp z,_lcd_putchar_eol2
    cp LCD_EOL_3                
    jp z,_lcd_putchar_eol3
    ; loop until EOL
    jr _lcd_putchar_pad 
_lcd_putchar_printable:
    call lcd_putdata
; check for overflow - DDRAM address returned in A
    cp LCD_EOL_0                
    jp z,_lcd_putchar_eol0
    cp LCD_EOL_1                
    jp z,_lcd_putchar_eol1
    cp LCD_EOL_2                
    jp z,_lcd_putchar_eol2
    cp LCD_EOL_3                
    jp z,_lcd_putchar_eol3
    jp _lcd_putchar_end
_lcd_putchar_eol0:
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_1_ADDR
	call lcd_putcmd
    jr _lcd_putchar_end
_lcd_putchar_eol1:
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_2_ADDR
	call lcd_putcmd
    jr _lcd_putchar_end
_lcd_putchar_eol2:
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
	call lcd_putcmd
    jr _lcd_putchar_end
_lcd_putchar_eol3:
    call lcd_scroll
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
	call lcd_putcmd
_lcd_putchar_end:
    ret

; transmit character in A to the data port, 
; return in A the DDRAM address where the character was sent
lcd_putdata:                     
    push bc
; save the transmit character
    ld b,a
_lcd_putdata_loop: 
; get the LCD status
    in a,(LCD_CTRL)
; busy ?
    bit 7,a
; yes
    jr nz,_lcd_putdata_loop
; no, reset the 'busy' bit and preserve the DDRAM address
    and %01111111
    ld c,a
; restore the transmit character and send it
    ld a,b
    out (LCD_DATA),a
; restore the DDRAM address
    ld a,c
    pop bc
    ret

lcd_scroll:
    push bc
    push de
    ld d,LCD_SET_DDRAM_ADDR+LCD_LINE_1_ADDR
    ld e,LCD_SET_DDRAM_ADDR+LCD_LINE_0_ADDR
    call _lcd_scroll_line
    ld d,LCD_SET_DDRAM_ADDR+LCD_LINE_2_ADDR
    ld e,LCD_SET_DDRAM_ADDR+LCD_LINE_1_ADDR
    call _lcd_scroll_line
    ld d,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
    ld e,LCD_SET_DDRAM_ADDR+LCD_LINE_2_ADDR
    call _lcd_scroll_line
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
    call _lcd_scroll_clear_line
    pop de
    pop bc
    ret
_lcd_scroll_line:
    ; b = character counter
    ; c = stash char
    ; d = source line to copy from
    ; e = destination line to copy to
    ld b,LCD_LINE_LEN
_lcd_scroll_line_loop:
    ld a,d ; source
    add b ; character counter is an offset
    dec a ; but we're zero based index so less 1
    call lcd_putcmd 
    call lcd_getchar
    ld c,a ; stash the value
    ld a,e ; destination
    add b ; character counter is an offset
    dec a ; but we're zero based index so less 1
    call lcd_putcmd 
    ld a,c ; recover the value
    call lcd_putdata
    djnz _lcd_scroll_line_loop
    ret
_lcd_scroll_clear_line:
    ; a = destination line to clear
    ; b = character counter
    ld b,LCD_LINE_LEN
    call lcd_putcmd 
_lcd_scroll_clear_line_loop:
    ld a,' '
    call lcd_putdata
    djnz _lcd_scroll_clear_line_loop
    ret
