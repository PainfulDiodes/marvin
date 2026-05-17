; bdfs_mon.asm - BDFS monitor presentation layer
;
; Wraps bdfs.asm pure functions with console output for the monitor.
; Command handlers (bdfs_mon_cmd_*) are called from monitor.asm dispatch stubs.

    IFDEF INCLUDE_BDFS

    INCLUDE "asm/chars.inc"
    INCLUDE "asm/bdfs.inc"

    PUBLIC bdfs_mon_format
    PUBLIC bdfs_mon_dir
    PUBLIC bdfs_mon_drive
    PUBLIC bdfs_mon_save

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN con_putchar_hex
    EXTERN con_putchar_dec
    EXTERN bdfs_select_drive
    EXTERN bdfs_format
    EXTERN bdfs_dir_open
    EXTERN bdfs_dir_next
    EXTERN bdfs_get_drive
    EXTERN bdfs_set_drive
    EXTERN bdfs_file_write
    EXTERN hex_byte_val
    EXTERN BDFS_DRIVE
    EXTERN BDFS_HDR_BUF
    EXTERN BDFS_ENT_BUF
    EXTERN flash_get_device_id
    EXTERN flash_get_device_name
    EXTERN flash_get_capacity_mb
    EXTERN bdfs_get_err_msg
    EXTERN RAMSTART
    EXTERN BDFS_SECTOR_SIZE

; bdfs_mon_format: 'f' command — confirm and format the current drive
; in:  HL = pointer into CMD_BUFFER past 'f' (optional volume name arg follows)
; out: — (all output already printed)
; destroys: AF, BC, DE, HL
bdfs_mon_format:
    ld a, (hl)
    cp ' '
    jr nz, _format_get_drive
    inc hl
    jr bdfs_mon_format
_format_get_drive:
    push hl                          ; save name pointer
    call bdfs_get_drive
    jr z, _format_confirm
    pop hl                           ; discard name ptr
    call _error                      ; A = BDFS_ERR_NO_DRIVE from bdfs_get_drive
    ret
_format_confirm:
    ld b, a                          ; save drive letter
    ld hl, _MSG_FORMAT_CONF_PRE
    call con_puts                    ; "Format "
    ld a, b
    call con_putchar                 ; drive letter
    ld hl, _MSG_FORMAT_CONF_POST
    call con_puts                    ; "? y/n "
    call con_getchar
    ld b, a                          ; save response before echo clobbers A
    call con_putchar                 ; echo
    ld a, CHAR_LF
    call con_putchar
    ld a, b
    cp 'y'
    jr z, _format_confirmed
    pop hl                           ; discard name ptr: user declined
    ret
_format_confirmed:
    pop hl                           ; restore name pointer
    ld a, (hl)
    or a
    jr nz, _format_execute
    ld hl, 0                         ; no name arg: use default
_format_execute:
    push hl                          ; save vol name ptr
    call bdfs_get_drive              ; A = drive letter (already confirmed valid above)
    call bdfs_select_drive
    jr z, _format_has_device
    pop hl                           ; discard vol name ptr
    call _error                      ; A = BDFS_ERR_NO_DEVICE from bdfs_select_drive
    ret
_format_has_device:
    ld hl, _MSG_FORMAT_PRE
    call con_puts                    ; "Formatting drive "
    ld a, (BDFS_DRIVE)
    call con_putchar
    ld a, CHAR_LF
    call con_putchar
    call _print_device_info          ; preserves HL
    pop hl                           ; restore vol name ptr
    call bdfs_format
    jr z, _format_completed
    call _error
    ret
_format_completed:
    ld hl, _MSG_FORMAT_OK
    call con_puts
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar
    ret

; bdfs_mon_dir: 'd' command — list current drive directory
; in:  —
; out: — (all output already printed)
; destroys: AF, BC, DE, HL
bdfs_mon_dir:
    call bdfs_get_drive
    jr z, _dir_has_drive
    call _error
    ret
_dir_has_drive:
    call bdfs_select_drive
    jr z, _dir_drive_selected
    call _error
    ret
_dir_drive_selected:
    call bdfs_dir_open
    jr z, _dir_opened
    call _error
    ret
_dir_opened:
    ; HL = vol name ptr from bdfs_dir_open
    call _print_device_info         ; preserves HL
    call con_puts                   ; print volume name (HL still points to it)
    ld a, CHAR_LF
    call con_putchar
_dir_scan:
    call bdfs_dir_next
    jr nz, _dir_done                ; NZ = BDFS_ERR_END_OF_DIR, C = count
    ; Z = entry found; check flags for deleted status
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _dir_item_deleted
    ; active entry
    ld hl, _MSG_INDENT
    call con_puts                   ; "  "
    call _print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _dir_scan
_dir_item_deleted:
    ld hl, _MSG_DELETED
    call con_puts                   ; "  (deleted) "
    call _print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _dir_scan
_dir_done:
    ld a, c
    call con_putchar_dec            ; C = active entry count from bdfs_dir_next
    ld hl, _MSG_FILES
    call con_puts                   ; " file(s)\n"
    ret

; bdfs_mon_drive: '@' command — select drive A-F
; in:  HL = pointer to drive letter char in CMD_BUFFER
; out: — (error message printed on invalid input)
; destroys: AF
bdfs_mon_drive:
    ld a, (hl)
    call bdfs_set_drive
    ret z
    call _error                     ; A = BDFS_ERR_BAD_DRIVE from bdfs_set_drive
    ret

; bdfs_mon_save: 's' command — save a region of RAM to the current drive as a named file
; in:  HL = pointer to CMD_BUFFER
; Syntax:  s <name.ext> [<hex-address> [<hex-length>]]
; Example: s HELLO.BAS 8000 0400
; Defaults: address=RAMSTART (8000), length=BDFS_SECTOR_SIZE (1000)
; out: — (all output already printed)
; destroys: AF, BC, DE, HL, IX
bdfs_mon_save:
    ld a, (hl)
    or a
    jp z, _save_bad_usage           ; null before any filename
    cp ' '
    jr nz, _save_got_filename
    inc hl
    jr bdfs_mon_save
_save_got_filename:
    push hl                         ; save filename ptr
_save_scan_name:
    ld a, (hl)
    or a
    jr z, _save_default_addr      ; null with no space: filename only, use defaults
    cp ' '
    jr z, _save_name_end
    inc hl
    jr _save_scan_name
_save_name_end:
    ld (hl), 0                      ; null-terminate filename in CMD_BUFFER
    inc hl
_save_find_addr_arg:
    ld a, (hl)
    or a
    jr z, _save_default_addr        ; no address — use RAMSTART
    cp ' '
    jr nz, _save_parse_addr_arg
    inc hl
    jr _save_find_addr_arg
_save_default_addr:
    ld de, RAMSTART
    ld bc, BDFS_SECTOR_SIZE
    jr _save_get_drive
_save_parse_addr_arg:
    call hex_byte_val               ; A = addr high byte; HL advances 2
    ld d, a
    call hex_byte_val               ; A = addr low byte; HL advances 2
    ld e, a                         ; DE = source address
_save_find_len_arg:
    ld a, (hl)
    or a
    jr z, _save_default_len         ; no length — use sector size
    cp ' '
    jr nz, _save_parse_len_arg
    inc hl
    jr _save_find_len_arg
_save_default_len:
    ld bc, BDFS_SECTOR_SIZE
    jr _save_get_drive
_save_parse_len_arg:
    call hex_byte_val               ; A = len high byte; HL advances 2
    ld b, a
    call hex_byte_val               ; A = len low byte; HL advances 2
    ld c, a                         ; BC = length; DE = source; stack: [FN]
_save_get_drive:
    call bdfs_get_drive
    jr z, _save_select_drive
    pop hl                          ; discard filename ptr
    call _error                     ; A = BDFS_ERR_NO_DRIVE from bdfs_get_drive
    ret
_save_select_drive:
    call bdfs_select_drive
    jr z, _save_excute
    pop hl                          ; discard filename ptr
    call _error                     ; A = BDFS_ERR_NO_DEVICE from bdfs_select_drive
    ret
_save_excute:
    pop hl                          ; HL = filename ptr
    push de                         ; save source addr for confirmation
    push bc                         ; save length for confirmation
    call bdfs_file_write            ; HL=filename, DE=source, BC=length; Z=ok NZ=error
    jr z, _save_done
    pop bc                          ; discard saved values on error
    pop de
    call _error
    ret
_save_done:
    pop bc                          ; BC = length used
    pop de                          ; DE = source addr used
    ld hl, _MSG_SAVED
    call con_puts                   ; "Saved "
    call _print_entry_name          ; print filename from BDFS_ENT_BUF
    ld a, ' '
    call con_putchar
    ld a, d
    call con_putchar_hex            ; source addr high byte
    ld a, e
    call con_putchar_hex            ; source addr low byte
    ld a, ' '
    call con_putchar
    ld a, b
    call con_putchar_hex            ; length high byte
    ld a, c
    call con_putchar_hex            ; length low byte
    ld a, CHAR_LF
    call con_putchar
    ret
_save_bad_usage:
    ld hl, _MSG_SAVE_USAGE
    call con_puts
    ret

; helpers

; _print_entry_name: print 8.3 filename from BDFS_ENT_BUF (e.g. "HELLO.TXT")
; destroys: -
_print_entry_name:
    push af
    push bc
    push hl
    ld hl, BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET
    ld b, BDFS_NAME_LEN
    call _print_entry_name_part
    ld a, (BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET)
    cp ' '                          ; ext field is space-padded: leading space means no extension
    jr z, _print_entry_name_done
    ld a, '.'
    call con_putchar
    ld hl, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN
    call _print_entry_name_part
_print_entry_name_done:
    pop hl
    pop bc
    pop af
    ret

; _print_entry_name_part: print at most B chars from (HL), stopping at first space (trims padding)
; in:  HL = source, B = max chars
; destroys: -
_print_entry_name_part:
    push af
    push hl
    push bc
_print_entry_name_part_loop:
    ld a, b
    or a
    jr z, _print_entry_name_part_done
    ld a, (hl)
    cp ' '
    jr z, _print_entry_name_part_done
    call con_putchar
    inc hl
    dec b
    jr _print_entry_name_part_loop
_print_entry_name_part_done:
    pop bc
    pop hl
    pop af
    ret

; _print_device_info: print label, capacity, and JEDEC ID e.g. "W25Q16 2MB [ef4015]\n"
; destroys: -
_print_device_info:
    push af
    push bc
    push de
    push hl
    call flash_get_device_name      ; HL = name string
    call con_puts
    ld a, ' '
    call con_putchar
    call flash_get_capacity_mb      ; A = MB
    call con_putchar_dec
    ld hl, _MSG_MB
    call con_puts
    call flash_get_device_id        ; A=mfr, B=type, C=cap
    call con_putchar_hex            ; print mfr
    ld a, b
    call con_putchar_hex            ; print type
    ld a, c
    call con_putchar_hex            ; print cap
    ld hl, _MSG_ID_CLOSE
    call con_puts
    pop hl
    pop de
    pop bc
    pop af
    ret

; _error: print error message for any BDFS_ERR_* code
; in:  A = BDFS_ERR_* code
; destroys: AF, HL
_error:
    call bdfs_get_err_msg
    ld a, h
    or l
    ret z                           ; no message for this code
    call con_puts
    ret

; strings

_MSG_FORMAT_CONF_PRE:   db "Format ", 0
_MSG_FORMAT_CONF_POST:  db "? y/n ", 0
_MSG_FORMAT_PRE:        db "Formatting drive ", 0
_MSG_FORMAT_OK:         db "Format ok - ", 0
_MSG_INDENT:            db "  ", 0
_MSG_DELETED:           db "  (deleted) ", 0
_MSG_FILES:             db " file(s)", CHAR_LF, 0
_MSG_MB:                db "MB [", 0
_MSG_ID_CLOSE:          db "]", CHAR_LF, 0
_MSG_SAVED:             db "Saved ", 0
_MSG_SAVE_USAGE:        db "s <name.ext> [<addr> [<len>]]", CHAR_LF, 0

    ENDIF
