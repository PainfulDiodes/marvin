; ****************************************************
; *  Marvin - a tiny monitor program for Z80 homebrew             
; * (c) Stephen Willcock 2024
; * https://github.com/PainfulDiodes
; ****************************************************

include "escapestring.asm"

; MAIN PROGRAM LOOP

ALIGN $10

start:
    ld de,$0000             ; point DE to zero - this is the default address argument for commands

    ld hl,welcome_msg
    call puts

prompt:
    ld hl,BUFFER            ; point HL to the beginning of the input buffer
    ld a,'>'
    call putchar 

get_cmd:
    call getchar            ; get character from console
    call putchar            ; echo the character to console
    cp _r                   ; is CR?
    jr z,get_cmd            ; yes - skip this
    cp _t                   ; is tab?
    jr z,get_cmd            ; yes - skip this
    cp ' '                  ; is space?
    jr z,get_cmd            ; yes - skip this
    cp _e                   ; escape?
    jr z, get_cmd_esc       ; yes
    cp _n                   ; end of line?
    jr z, get_cmd_end       ; yes
    ld(hl),a                ; no - add character to the buffer
    inc hl                  ; move pointer to next buffer location - we're not checking for overrun
    jr get_cmd              ; next character
get_cmd_esc:                ; do escape
    ld a,_n                 ; new line
    call putchar
    jr prompt               ; back to prompt
get_cmd_end:
    ld a,0                  ; string terminator
    ld(hl),a                ; add terminator to end of buffer

                            ; process command from buffer

    ld hl,BUFFER            ; point to start of buffer
    ld a,(hl)               ; load character from buffer
    cp 0                    ; end of string
    jr z,prompt             ; yes - empty line - go back to prompt
    inc hl                  ; advance the buffer pointer
    cp 'r'                  ; r = Read
    jr z,cmd_read
    cp 'w'                  ; w = Write
    jr z,cmd_write
    cp 'x'                  ; x = eXecute
    jr z,cmd_execute
    cp ':'                  ; : = load from intel hex format
    jr z,cmd_load
    ld hl,bad_cmd_msg       ; otherwise error
    call puts
    jp prompt               ; loop back to the prompt


; COMMANDS

; READ

cmd_read:                   ; read bytes from memory and send hex values to console
    ld a,(hl)               ; load character from buffer
    cp 0                    ; end of string?
    jr z, cmd_read_row      ; yes - no address argument, so skip to read row
    call hex_byte           ; parse first pair of characters
    ld d,a                  ; load into upper byte of memory pointer
    call hex_byte           ; parse second pair of characters
    ld e,a                  ; load into lower byte of memory pointer
cmd_read_row:
    ld c, 0x10              ; initialise byte counter - each row will have this many bytes
    ld a,d                  ; print DE content: the read address
    call putchar_hex
    ld a,e
    call putchar_hex
    ld a,':'                ; separator between address and data
    call putchar
    ld a,' '
    call putchar
cmd_read_byte:            
    ld a,(de)               ; get a byte
    call putchar_hex        ; and print it
    ld a,' '                ; add space between bytes
    call putchar
    inc de                  ; next address
    dec c                   ; reduce byte counter
    jr nz, cmd_read_byte    ; repeat if the counter is not 0
    ld a,_n                 ; otherwise, new line
    call putchar    
    jp prompt               ; and back to prompt

; WRITE

cmd_write:                  ; write bytes to memory interpreting hex values from console
    ld a,(hl)               ; load character from buffer
    cp 0                    ; end of string?
    jr z, cmd_write_null    ; yes - no data
    call hex_byte           ; parse first pair of characters - address high
    ld d,a                  ; load into upper byte of memory pointer
    call hex_byte           ; parse second pair of characters - address low
    ld e,a                  ; load into lower byte of memory pointer
cmd_write_data:
    ld a,(hl)               ; load character from buffer
    cp 0                    ; end of string?
    jr z, cmd_write_end     ; yes - we're done
    call hex_byte           ; parse data byte
    ld (de),a               ; write byte to memory
    inc de                  ; advance destination pointer
    jr cmd_write_data
cmd_write_end:              ; 
    jp prompt               ; and back to prompt
cmd_write_null:             ; w with no data
    ld hl,cmd_w_null_msg
    call puts
    jp prompt               ; and back to prompt

; EXECUTE

cmd_execute:                ; start executing from given address
    ld a,(hl)               ; load character from buffer
    cp 0                    ; end of string?
    jp z, cmd_exec_df       ; yes - no data
    call hex_byte           ; parse first pair of characters - address high
    ld d,a                  ; load into upper byte of memory pointer
    call hex_byte           ; parse second pair of characters - address low
    ld e,a                  ; load into lower byte of memory pointer
    ld hl,de
    jp (hl)                 ; execute from address
cmd_exec_df:                ; start executing from default address
    ld hl,RAMSTART
    jp (hl)                 ; execute from address

; LOAD

cmd_load:                   ; load from INTEL HEX - records are read from the buffer
    ld a,(hl)               ; load character from buffer
    cp 0                    ; end of string?
    jp z, cmd_load_end      ; yes - no data - quit
    call hex_byte           ; parse first pair of characters - byte count
    cp 0 
    jp z, cmd_load_end      ; yes - zero byte count - quit 
    ld c,a                  ; load byte count into C
    call hex_byte           ; parse address high
    ld d,a                  ; load into upper byte of memory pointer
    call hex_byte           ; parse address low
    ld e,a                  ; load into lower byte of memory pointer
    call hex_byte           ; parse record type
    cp 0                    ; record type zero?
    jp nz, cmd_load_end     ; no - quit 
cmd_load_data:
    ld a,(hl)               ; load character from buffer
    cp 0                    ; end of string?
    jr z, cmd_load_end      ; yes - we're done
    call hex_byte           ; parse data byte
    ld (de),a               ; write byte to memory
    inc de                  ; advance destination pointer
    dec c                   ; decrement byte counter
    jr nz,cmd_load_data     ; if byte counter not zero then go again
cmd_load_end:               ; 
    jp prompt               ; and back to prompt

; SUBROUTINES

hex_byte:                   ; read 2 bytes from HL pointer, return converted value in A and advance pointer
    push bc                 ; preserve BC
    ld a,(hl)               ; load 1st character from memory
    cp 0                    ; end of string?
    jr z,hex_byte_zero      ; yes - no value, so return zero
    inc hl                  ; advance the buffer pointer
    call hex_to_num         ; convert first hex digit
    sla a                   ; shift left 4 bits to put value into top nibble
    sla a
    sla a
    sla a
    ld b,a                  ; cache the result
    ld a,(hl)               ; load 2nd character from memory
    cp 0                    ; end of string?
    jr z,hex_byte_zero      ; yes - incomplete byte, so return zero 
    inc hl                  ; advance the buffer pointer
    call hex_to_num         ; no - convert 2nd hex digit
    add a,b                 ; add first and second digits
    pop bc                  ; restore BC
    ret
hex_byte_zero:
    ld a,0                  ; zero return value
    pop bc                  ; restore BC
    ret

hex_to_num:                 ; convert an ASCII char in A to a number (lower 4 bits)
    cp 'a'                  ; is it lowercase alphabetic?
    jr c,hex_to_num_un      ; no - uppercase/numeric
    sub 'a'-0x0a            ; yes - alphabetic
    ret
hex_to_num_un:
    cp 'A'                  ; is it uppercase alphabetic?
    jr c,hex_to_num_n       ; no - numeric
    sub 'A'-0x0a            ; numeric
    ret
hex_to_num_n:
    sub '0'                 ; numeric
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
    add a,'W'               ; for alpha add the base ascii for 'a' but then sub 10 as hex 'a' is 10d => 'W'
    call putchar
    ret
putchar_hex_n:
    add a,'0'               ; for numeric add the base ascii for '0'
    call putchar
    ret


; STRINGS

welcome_msg:    db "MARVIN v1.1.beta\n"
                db "A simple Z80 homebrew monitor program\n"
                db "(c) Stephen Willcock 2024\n"
                db "https://github.com/PainfulDiodes\n\n",0

bad_cmd_msg:    db "Command not recognised\n",0

cmd_w_null_msg: db "No data to write\n",0
