; ****************************************************
; *  Marvin - a Z80 homebrew monitor program
; * (c) Stephen Willcock 2024
; * https://github.com/PainfulDiodes
; ****************************************************

; MAIN PROGRAM LOOP

ALIGN $10

start:
    ; point DE to zero - this is the default address argument for commands
    ld de,$0000

    ld hl,welcome_msg
    call puts

prompt:
    ; point HL to the beginning of the input buffer
    ld hl,CMD_BUFFER            
    ld a,'>'
    call putchar 

_get_cmd:
    ; get character from console
    call getchar
    ; echo the character to console
    call putchar
    ; is CR?
    cp ESC_R
    ; yes: skip this
    jr z,_get_cmd
    ; is tab?
    cp ESC_T
    ; yes: skip this
    jr z,_get_cmd
    ; is space?
    cp ' '
    ; yes - skip this
    jr z,_get_cmd
    ; escape?
    cp ESC_E
    ; yes
    jr z, _get_cmd_esc
    ; end of line?
    cp ESC_N
    ; yes
    jr z, _get_cmd_end       
    ; no: add character to the buffer
    ld(hl),a
    ; move pointer to next buffer location - we're not checking for overrun
    inc hl
    ; next character
    jr _get_cmd
    ; do escape
_get_cmd_esc:
    ; new line
    ld a,ESC_N
    call putchar
    ; back to prompt
    jr prompt
_get_cmd_end:
    ; string terminator
    ld a,0                  
    ; add terminator to end of buffer
    ld(hl),a
; process command from buffer
    ; point to start of buffer
    ld hl,CMD_BUFFER
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes - empty line - go back to prompt
    jr z,prompt
    ; advance the buffer pointer
    inc hl
    cp 'r'
    jr z,_cmd_read
    cp 'w'
    jr z,_cmd_write
    cp 'x'
    jr z,_cmd_execute
    ; ':' = load from intel hex format
    cp ':' 
    jr z,_cmd_load
    ; otherwise error
    ld hl,bad_cmd_msg
    call puts
    ; loop back to the prompt
    jp prompt

; COMMANDS

; READ
; read bytes from memory and send hex values to console
_cmd_read:                   
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: no address argument, so skip to read row
    jr z, _cmd_read_row
    ; parse first pair of characters
    call hex_byte
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters
    call hex_byte
    ; load into lower byte of memory pointer
    ld e,a
_cmd_read_row:
    ; initialise byte counter - each row will have this many bytes
    ld c, $10
    ; print DE content: the read address
    ld a,d
    call putchar_hex
    ld a,e
    call putchar_hex
    ; separator between address and data
    ld a,':'
    call putchar
    ld a,' '
    call putchar
    ; get a byte
_cmd_read_byte:            
    ld a,(de)
    ; and print it
    call putchar_hex
    ; add space between bytes
    ld a,' '
    call putchar
    ; next address
    inc de
    ; reduce byte counter
    ; TODO djnz ?
    dec c
    ; repeat if the counter is not 0
    jr nz, _cmd_read_byte
    ; otherwise, new line
    ld a,ESC_N
    call putchar
    ; and back to prompt
    jp prompt

; WRITE

; write bytes to memory interpreting hex values from console
_cmd_write:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: no data
    jr z, _cmd_write_null
    ; parse first pair of characters - address high
    call hex_byte
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters - address low
    call hex_byte
    ; load into lower byte of memory pointer
    ld e,a
_cmd_write_data:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: we're done
    jr z, _cmd_write_end
    ; parse data byte
    call hex_byte
    ; write byte to memory
    ld (de),a
    ; advance destination pointer
    inc de
    jr _cmd_write_data
_cmd_write_end:
    jp prompt
    ; w with no data
_cmd_write_null:        
    ld hl,cmd_w_null_msg
    call puts
    ; and back to prompt
    jp prompt

; EXECUTE

; start executing from given address
_cmd_execute:                
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes - no data
    jp z, _cmd_exec_df
    ; parse first pair of characters - address high
    call hex_byte
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters - address low
    call hex_byte
    ; load into lower byte of memory pointer
    ld e,a
    ld hl,de
    ; execute from address
    jp (hl)
    ; start executing from default address
_cmd_exec_df:
    ld hl,RAMSTART
    ; execute from address
    jp (hl)

; LOAD

; load from INTEL HEX - records are read from the buffer
_cmd_load:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: no data - quit
    jp z, _cmd_load_end
    ; parse first pair of characters - byte count
    call hex_byte
    cp 0 
    ; yes - zero byte count - quit 
    jp z, _cmd_load_end
    ; load byte count into C
    ld c,a
    ; parse address high
    call hex_byte
    ; load into upper byte of memory pointer
    ld d,a
    ; parse address low
    call hex_byte
    ; load into lower byte of memory pointer
    ld e,a
    ; parse record type
    call hex_byte
    ; record type zero?
    cp 0
    ; no: quit 
    jp nz, _cmd_load_end
_cmd_load_data:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: we're done
    jr z, _cmd_load_end
    ; no:
    ; parse data byte
    call hex_byte
    ; write byte to memory
    ld (de),a
    ; advance destination pointer
    inc de
    ; decrement byte counter
    ; TODO djnz
    dec c
    ; if byte counter not zero then go again
    jr nz,_cmd_load_data
_cmd_load_end:
    jp prompt

; SUBROUTINES

; read 2 bytes from HL pointer, return converted value in A and advance pointer
hex_byte:
    ; preserve BC
    push bc
    ; load 1st character from memory
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: no value - return zero
    jr z,_hex_byte_zero
    ; no:
    ; advance the buffer pointer
    inc hl
    ; convert first hex digit
    call hex_to_num
    ; shift left 4 bits to put value into top nibble
    sla a
    sla a
    sla a
    sla a
    ; cache the result
    ld b,a
    ; load 2nd character from memory
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: incomplete byte - return zero 
    jr z,_hex_byte_zero
    ; advance the buffer pointer
    inc hl
    ; and convert 2nd hex digit
    call hex_to_num         
    ; add first and second digits
    add a,b
    ; restore BC
    pop bc
    ret
_hex_byte_zero:
    ; zero return value
    ld a,0
    ; restore BC
    pop bc
    ret

; convert an ASCII hex char in A to a number value (lower 4 bits)
hex_to_num:
    ; is it lowercase alphabetic?
    cp 'a'                  
    ; no: uppercase/numeric
    jr c,_hex_to_num_un
    ; yes: alphabetic
    sub 'a'-$0a
    ret
_hex_to_num_un:
    ; is it uppercase alphabetic?
    cp 'A'
    ; no: numeric
    jr c,_hex_to_num_n       
    ; y:
    sub 'A'-$0a
    ret
_hex_to_num_n:
    ; numeric
    sub '0'
    ret

putchar_hex:
    ; stash in B
    ld b,a
    ; shift A right x4 e.g. transform 10110010 to 00001011
    srl a
    srl a
    srl a
    srl a
    ; most significant digit
    call _putchar_hex_dgt
    ; recover from stash
    ld a,b
    ; clear the top 4 bits
    and %00001111
    ; least significant digit
    call _putchar_hex_dgt
    ret
_putchar_hex_dgt:
    ; is it an alpha or numeric?
    cp $0a
    ; numeric
    jr c,_putchar_hex_n
    ; alpha
    ; for alpha add the base ascii for 'a' but then sub 10 / $0a as hex 'a' = 10d
    add a,'a'-$0a
    call putchar
    ret
_putchar_hex_n:
    ; for numeric add the base ascii for '0'
    add a,'0'
    call putchar
    ret

; TODO move functions into separate file

; STRINGS

alt_welcome_msg:
                db "MARVIN v1.1.beta\n"
                db "A simple Z80 homebrew monitor program\n"
                db "(c) Stephen Willcock 2024\n"
                db "https://github.com/PainfulDiodes\n\n",0

welcome_msg:    
                db "PainfulDiodes\n"
                db "MARVIN Z80 monitor\n"
                db "v1.1.beta\n",0

bad_cmd_msg:    
                db "Command not recognised\n",0

cmd_w_null_msg: 
                db "No data to write\n",0
