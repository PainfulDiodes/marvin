; **********************************************************************
; *  Marvin - a tiny Z80 monitor program                             
; **********************************************************************

start:
    ld de,$0000             ; point DE to zero - this is the default memory pointer for command arguments

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

                            ; process command from buffer
    ld hl,BUFFER            ; point to start of buffer
    ld a,(hl)               ; load character from buffer
    inc hl                  ; advance the buffer pointer
    cp "r"                  ; r = read
    jr z,cmd_read
    ld hl,bad_cmd_msg       ; otherwise error
    call puts
    jp prompt               ; loop back to the prompt

cmd_read:                   ; read bytes from memory and send hex values to console
    ld a,(hl)               ; load character from buffer
    inc hl                  ; advance the buffer pointer
    cp "\n"                 ; is new line?
    jr z,cmd_read_start     ; yes - continue with current pointer

    call hex_to_num         ; no - there's an argument - so convert first hex digit
    ld e,a                  ; copy result to pointer
;
;    ld a,(hl)               ; load character from buffer
;    inc hl                  ; advance the buffer pointer
;    cp "\n"                 ; is new line?
;    jr z,cmd_read_start     ; yes - continue with current pointer 
;
;    sll e                   ; shift left x4 to move number to top nibble
;    sll e
;    sll e
;    sll e
;    call hex_to_num         ; convert next hex digit
;    add e,a

cmd_read_start:
    ld c, 0x10              ; initialise byte counter - each row will have this many bytes
    ld a,d                  ; print DE content: the read address
    call putchar_hex
    ld a,e
    call putchar_hex
    ld a,":"                ; separator between address and data
    call putchar
    ld a," "
    call putchar
cmd_read_loop:            
    ld a,(de)               ; get a byte
    call putchar_hex        ; and print it
    ld a," "                ; add space between bytes
    call putchar
    inc de                  ; next address
    dec c                   ; reduce byte counter
    jr nz, cmd_read_loop    ; repeat if the counter is not 0
    ld a, "\n"              ; otherwise, new line
    call putchar    
    jp prompt               ; and back to prompt

hex_to_num:                  ; convert an ASCII char in A to a number (lower 4 bits)
    cp "a"                   ; is it alphabetic?
    jr c,hex_to_num_n        ; no - numeric
    sub "W"                ; yes - alphabetic
    ret
hex_to_num_n:
    sub "0"                ; numeric
    ret

putchar_hex:
    ld b,a                  ; copy into B
    srl a                   ; shift A right x4 e.g. transform 10110010 to 00001011
    srl a
    srl a
    srl a
    call putchar_hex_dgt    ; most significant digit
    ld a,b                  ; get the original copy back
    and %00001111           ; clears the top 4 bits
    call putchar_hex_dgt    ; least significant digit
    ret
putchar_hex_dgt:
    cp 0x0a                 ; is it an alpha or numeric?
    jr c,putchar_hex_n      ; numeric
                            ; or drop through to alpha
    add a,"W"               ; for alpha add the base ascii for 'a' but then sub 10 as hex 'a' is 10d => 'W'
    call putchar
    ret
putchar_hex_n:
    add a,"0"               ; for numeric add the base ascii for '0'
    call putchar
    ret

welcome_msg:    .db "MARVIN\n"
                .db "A super simple monitor program for Z80 homebrew\n"
                .db "(c) Stephen Willcock 2024\n"
                .db "https://github.com/PainfulDiodes\n\n",0

bad_cmd_msg:    .db "Command not recognised\n",0
