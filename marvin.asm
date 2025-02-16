; **********************************************************************
; *  Marvin - a tiny Z80 monitor program                             
; **********************************************************************

start:
    ld de,$0000             ; point DE to zero - this is the default memory pointer for command arguments

welcome:
    ld hl,welcome_msg
    call puts

prompt:
    ld hl,BUFFER            ; point HL to the beginning of the input buffer
    ld a,">"
    call putchar 

get_cmd:
    call getchar            ; get character from console
    call putchar            ; echo the character to console
    ld(hl),a                ; add character to the buffer
    inc hl                  ; move pointer to next buffer location - we're not checking for overrun           
    cp "\n"                 ; end of line?
    jr nz, get_cmd          ; no - loop for next character
                            ; yes - end of line - drop though to next instruction

proc_cmd:               
    ld hl,BUFFER            ; point to start of buffer
    ld a,(hl)               ; load character from buffer
    cp "r"                  ; r = read
    jr z,cmd_read
    ld a, "?"               ; otherwise error
    call putchar
    ld a, "\n"
    call putchar
    jp prompt               ; loop back to the prompt

cmd_read:                   ; read bytes from memory and send hex values to console
    ld c, 0x10              ; initialise byte counter - each row will have this many bytes
    ld a,d                  ; print DE content: the read address
    call prt_hex
    ld a,e
    call prt_hex
    ld a,":"                ; separator between address and data
    call putchar
    ld a," "
    call putchar
cmd_rd_lp:            
    ld a,(de)               ; get a byte
    call prt_hex            ; and print it
    ld a," "                ; add space between bytes
    call putchar
    inc de                  ; next address
    dec c                   ; reduce byte counter
    jr nz, cmd_rd_lp        ; repeat if the counter is not 0
    ld a, "\n"              ; otherwise, new line
    call putchar    
    jp prompt               ; and back to prompt
prt_hex:
    ld b,a                  ; copy into B
    srl a                   ; shift A right x4 e.g. transform 10110010 to 00001011
    srl a
    srl a
    srl a
    call prt_hex_dgt        ; most significant digit
    ld a,b                  ; get the original copy back
    and %00001111           ; clears the top 4 bits
    call prt_hex_dgt        ; least significant digit
    ret
prt_hex_dgt:
    cp 0x0a                 ; is it an alpha or numeric?
    jr c,prt_hex_n          ; numeric
prt_hex_a:                  ; or drop through to alpha
    add a,"W"               ; for alpha add the base ascii for 'a' but then sub 10 as hex 'a' is 10d => 'W'
    call putchar
    ret
prt_hex_n:
    add a,"0"               ; for numeric add the base ascii for '0'
    call putchar
    ret
welcome_msg: .db "MARVIN\n"
             .db "A super simple monitor program for Z80 homebrew\n"
             .db "(c) Stephen Willcock 2024\n"
             .db "https://github.com/PainfulDiodes\n\n",0
end: