; **********************************************************************
; *  Marvin - a tiny Z80 monitor program                             
; **********************************************************************

SIO_CTRL .equ 0         ; serial control register address
SIO_DATA .equ 1         ; serial data register address
BUFFER .equ 0x8000      ; start of RAM
STACK .equ 0xffff       ; this should really be 0x0000 as the CPU will dec SP before PUSH

start:
    ld de,0             ; point DE to zero - this is the default location for the read command
    ld sp, STACK
ready_chk:
    in a,(SIO_CTRL)     ; read the serial control register
    bit 0,a             ; check bit 0 - ready to write
    jp nz,ready_chk     ; loop back if not ready
welcome:
    ld hl,start_msg
    call prt_str
new_prompt:
    ld hl,BUFFER        ; point HL to the beginning of the input buffer
    ld a,">"
    out (SIO_DATA),a 
get_char:
    in a,(SIO_CTRL)     ; read the serial control register
    bit 1,a             ; check bit 1 - receive character available
    jp nz,get_char      ; loop back if nothing to read
    in a,(SIO_DATA)     ; read a character
    out (SIO_DATA),a    ; echo the character
    ld(hl),a            ; add to the buffer
    inc hl              ; move pointer to next buffer location - we're not checking for overrun           
    cp "\n"
    jr nz, get_char     ; next character if not newline
proc_cmd:               ; drop through here on newline
    ld hl,BUFFER        ; point to start of buffer
    ld a,(hl)           ; load character from buffer
    cp "r"              ; r = read
    jr z,rd_start
    ld a, "?"           ; otherwise error
    out (SIO_DATA),a
    ld a, "\n"
    out (SIO_DATA),a
    jp new_prompt       ; loop back to the prompt
rd_start:
    ld c, 0x10          ; initialise byte counter - each row will have this many bytes
rd_start_ln:
    ld a,d              ; print DE content: the read address
    call prt_hex
    ld a,e
    call prt_hex
    ld a,":"
    out(SIO_DATA),a
    ld a," "
    out(SIO_DATA),a
rd_ln_loop:            
    ld a,(de)           ; get a byte
    call prt_hex        ; and print it
    ld a," "            ; add space between bytes
    out (SIO_DATA),a
    inc de              ; next address
    dec c               ; reduce byte counter
    jr nz, rd_ln_loop   ; repeat if the counter is not 0
    ld a, "\n"          ; otherwise, new line
    out (SIO_DATA),a    
    jp new_prompt       ; and back to prompt
prt_hex:
    ld b,a              ; copy into B
    srl a               ; shift A right x4 e.g. transform 10110010 to 00001011
    srl a
    srl a
    srl a
    call prt_hex_dgt    ; most significant digit
    ld a,b              ; get the original copy back
    and %00001111       ; clears the top 4 bits
    call prt_hex_dgt    ; least significant digit
    ret
prt_hex_dgt:
    cp 0x0a             ; is it an alpha or numeric?
    jr c,prt_hex_n      ; numeric
prt_hex_a:              ; or drop through to alpha
    add a,"W"           ; for alpha add the base ascii for 'a' but then sub 10 as hex 'a' is 10d => 'W'
    out (SIO_DATA),a
    ret
prt_hex_n:
    add a,"0"           ; for numeric add the base ascii for '0'
    out (SIO_DATA),a
    ret
prt_str:                ; print a zero-terminated string, start pointed to by hl
    ld a,(hl)
    cp 0h
    ret z
    out(SIO_DATA),a 
    inc hl
    jp prt_str
start_msg   .db "MARVIN\n"
            .db "A super simple monitor program for Z80 homebrew\n"
            .db "(c) Stephen Willcock 2024\n"
            .db "https://github.com/PainfulDiodes\n\n",0
end: