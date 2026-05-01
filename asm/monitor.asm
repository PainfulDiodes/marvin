    INCLUDE "asm/chars.inc"

    EXTERN CMD_BUFFER, RAMSTART
    EXTERN STACK

    PUBLIC marvin_coldstart
    PUBLIC marvin_warmstart

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN hex_byte_val
    EXTERN con_putchar_hex
    EXTERN WELCOME_MSG
    EXTERN BAD_CMD_MSG
    EXTERN CMD_W_NULL_MSG
    EXTERN HELP_MSG
    IFDEF INCLUDE_BASIC
    EXTERN BASIC_PROMPT_MSG
    EXTERN START
    EXTERN WARM
    ENDIF
    IFDEF INCLUDE_BDFS
    EXTERN bdfs_format
    EXTERN bdfs_dir
    EXTERN bdfs_set_drive
    EXTERN bdfs_get_drive
    EXTERN BDFS_DRIVE
    EXTERN BDFS_HELP_MSG
    ENDIF

; ****************************************************
; *  Marvin - a Z80 homebrew monitor program
; * (c) Stephen Willcock 2024
; * https://github.com/PainfulDiodes
; ****************************************************

; MAIN PROGRAM LOOP

marvin_coldstart:
    ld hl,WELCOME_MSG
    call con_puts
    IFDEF INCLUDE_BDFS
    ld a, 'A'
    ld (BDFS_DRIVE), a
    ENDIF

marvin_warmstart:
    ld sp, STACK
    ; point DE to zero - this is the default address argument for commands
    ld de,0x0000
_prompt:
    ; point HL to the beginning of the input buffer
    ld hl,CMD_BUFFER
    IFDEF INCLUDE_BDFS
    ld a, (BDFS_DRIVE)
    or a
    jr z, _prompt_no_drive
    call con_putchar            ; drive letter
_prompt_no_drive:
    ENDIF
    ld a,'>'
    call con_putchar

_get_cmd:
    ; get character from console
    call con_getchar
    ; backspace? handle before echo (CHAR_BS or CHAR_DEL - Mac keyboard sends DEL)
    cp CHAR_BS
    jr z,_get_cmd_bs
    cp CHAR_DEL
    jr z,_get_cmd_bs
    ; echo the character to console
    call con_putchar
    ; is CR?
    cp CHAR_CR
    ; yes: skip this
    jr z,_get_cmd
    ; is tab?
    cp CHAR_TAB
    ; yes: skip this
    jr z,_get_cmd
    ; escape?
    cp CHAR_ESC
    ; yes
    jr z, _get_cmd_esc
    ; end of line?
    cp CHAR_LF
    ; yes
    jr z, _get_cmd_end       
    ; no: add character to the buffer
    ld(hl),a
    ; move pointer to next buffer location - we're not checking for overrun
    inc hl
    ; next character
    jr _get_cmd
_get_cmd_bs:
    ; don't move pointer back if already at start of buffer
    ld bc,CMD_BUFFER
    or a                    ; clear carry flag
    sbc hl,bc               ; HL - CMD_BUFFER; sets Z if at start
    jr z,_get_cmd_bs_end    ; at start: don't echo, don't move
    dec hl                  ; move pointer back one position
    add hl,bc               ; restore HL
    ld a,CHAR_BS              ; BS: move cursor back
    call con_putchar
    ld a,' '                ; space: erase character
    call con_putchar
    ld a,CHAR_BS              ; BS: reposition cursor
    call con_putchar
    jr _get_cmd
_get_cmd_bs_end:
    add hl,bc               ; restore HL (= CMD_BUFFER)
    jr _get_cmd
    ; do escape
_get_cmd_esc:
    ; new line
    ld a,CHAR_LF
    call con_putchar
    ; back to prompt
    jr _prompt
_get_cmd_end:
    ; string terminator
    ld a,0                  
    ; add terminator to end of buffer
    ld(hl),a
; process command from buffer
    ; point to start of buffer
    ld hl,CMD_BUFFER
_cmd_skip_space:
    ; load character from buffer
    ld a,(hl)
    ; skip leading spaces
    cp ' '
    jr nz,_cmd_check
    inc hl
    jr _cmd_skip_space
_cmd_check:
    ; end of string?
    cp 0
    ; yes - empty line - go back to prompt
    jr z,_prompt
    ; advance the buffer pointer
    inc hl
    cp 'r'
    jr z,_cmd_read
    cp 'w'
    jr z,_cmd_write
    cp 'x'
    jp z,_cmd_execute
    IFDEF INCLUDE_BASIC
    cp 'b'
    jp z,_cmd_basic_cold
    cp 'B'
    jp z,_cmd_basic_warm
    ENDIF
    ; ':' = load from intel hex format
    cp ':'
    jp z,_cmd_load
    IFDEF INCLUDE_BDFS
    cp 'f'
    jp z,_cmd_format
    cp 'd'
    jp z,_cmd_dir
    cp '@'
    jp z,_cmd_drive
    ENDIF
    cp '?'
    jp z,_cmd_help
_cmd_bad:
    ; otherwise error
    ld hl,BAD_CMD_MSG
    call con_puts
    ; loop back to the prompt
    jp _prompt

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
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters
    call hex_byte_val
    ; load into lower byte of memory pointer
    ld e,a
_cmd_read_row:
    ; initialise byte counter - each row will have this many bytes
    ld c, 0x10
    ; print DE content: the read address
    ld a,d
    call con_putchar_hex
    ld a,e
    call con_putchar_hex
    ; separator between address and data
    ld a,':'
    call con_putchar
    ld a,' '
    call con_putchar
    ; get a byte
_cmd_read_byte:            
    ld a,(de)
    ; and print it
    call con_putchar_hex
    ; add space between bytes
    ld a,' '
    call con_putchar
    ; next address
    inc de
    ; reduce byte counter
    ; TODO djnz ?
    dec c
    ; repeat if the counter is not 0
    jr nz, _cmd_read_byte
    ; otherwise, new line
    ld a,CHAR_LF
    call con_putchar
    ; and back to prompt
    jp _prompt

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
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters - address low
    call hex_byte_val
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
    call hex_byte_val
    ; write byte to memory
    ld (de),a
    ; advance destination pointer
    inc de
    jr _cmd_write_data
_cmd_write_end:
    jp _prompt
    ; w with no data
_cmd_write_null:        
    ld hl,CMD_W_NULL_MSG
    call con_puts
    ; and back to prompt
    jp _prompt

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
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters - address low
    call hex_byte_val
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
    call hex_byte_val
    cp 0 
    ; yes - zero byte count - quit 
    jp z, _cmd_load_end
    ; load byte count into C
    ld c,a
    ; parse address high
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse address low
    call hex_byte_val
    ; load into lower byte of memory pointer
    ld e,a
    ; parse record type
    call hex_byte_val
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
    call hex_byte_val
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
    jp _prompt

    IFDEF INCLUDE_BDFS

; FORMAT
; f [name] = format current drive (select with @A-@F first); prompts for confirmation
_cmd_format:
    ; skip spaces, find optional volume name argument
_cmd_format_skip_sp:
    ld a, (hl)
    cp ' '
    jr nz, _cmd_format_got_arg
    inc hl
    jr _cmd_format_skip_sp
_cmd_format_got_arg:
    push hl                         ; save name pointer

    call bdfs_get_drive
    or a
    jr nz, _cmd_format_confirm
    pop hl                          ; discard name ptr
    jp _cmd_bad
_cmd_format_confirm:
    ld b, a                         ; save drive letter
    ld hl, _msg_fmt_confirm_pre
    call con_puts                   ; "Format "
    ld a, b
    call con_putchar                ; drive letter
    ld hl, _msg_fmt_confirm_post
    call con_puts                   ; "? y/n "
    call con_getchar
    ld b, a                         ; save response before echo clobbers A
    call con_putchar                ; echo
    ld a, CHAR_LF
    call con_putchar
    ld a, b
    cp 'y'
    jr z, _cmd_format_confirmed
    pop hl                          ; discard name ptr: user declined
    jp _prompt
_cmd_format_confirmed:
    pop hl                          ; restore name pointer

    ld a, (hl)
    or a
    jr nz, _cmd_format_run
    ld hl, 0                        ; no name arg: use default
_cmd_format_run:
    call bdfs_format
    jp _prompt

; DIR
; d = list directory of current drive (select with @A-@F first)
_cmd_dir:
    call bdfs_dir
    jp _prompt

; DRIVE SELECT
; @A-@F or @a-@f = select drive A-F
_cmd_drive:
    ld a, (hl)
    and 0dfh                        ; fold lowercase to uppercase
    cp 'A'
    jp c, _cmd_bad
    cp 'G'
    jp nc, _cmd_bad
    call bdfs_set_drive
    jp _prompt

_msg_fmt_confirm_pre:   db "Format ", 0
_msg_fmt_confirm_post:  db "? y/n ", 0

    ENDIF

    IFDEF INCLUDE_BASIC

; BASIC

; b: BBC BASIC cold start, B: warm start
_cmd_basic_cold:
    ld a,CHAR_LF
    call con_putchar
    jp START
_cmd_basic_warm:
    ld a,CHAR_LF
    call con_putchar
    jp WARM

    ENDIF

; HELP

; ? = show command summary
_cmd_help:
    ld hl, HELP_MSG
    call con_puts
    IFDEF INCLUDE_BDFS
    ld hl, BDFS_HELP_MSG
    call con_puts
    ENDIF
    jp _prompt