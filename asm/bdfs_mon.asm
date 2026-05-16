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

    PUBLIC BDFS_NO_DRIVE_MSG

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
    call _mon_dir
    ret

; bdfs_mon_drive: '@' command — select drive A-F
; in:  HL = pointer to drive letter char in CMD_BUFFER
; out: — (error message printed on invalid input)
; destroys: AF
bdfs_mon_drive:
    ld a, (hl)
    and 0dfh                         ; fold lowercase to uppercase
    cp 'A'
    jr c, _bmcd_bad
    cp 'G'
    jr nc, _bmcd_bad
    call bdfs_set_drive
    ret

_bmcd_bad:
    ld hl, _MSG_BAD_DRIVE
    call con_puts
    ret

; bdfs_mon_save: 's' command — save a region of RAM to the current drive as a named file
; in:  HL = pointer past 's' in CMD_BUFFER
; Syntax:  s <name.ext> <hex-address> <hex-length>
; Example: s HELLO.BAS 8000 0400
; out: — (all output already printed)
; destroys: AF, BC, DE, HL, IX
bdfs_mon_save:
_bms_skip_sp:
    ld a, (hl)
    cp ' '
    jr nz, _bms_got_filename
    inc hl
    jr _bms_skip_sp
_bms_got_filename:
    push hl                         ; [FN] save filename ptr
_bms_scan_name:
    ld a, (hl)
    or a
    jr z, _bms_bad_args_pop         ; null with no space: no args
    cp ' '
    jr z, _bms_name_end
    inc hl
    jr _bms_scan_name
_bms_name_end:
    ld (hl), 0                      ; null-terminate filename in CMD_BUFFER
    inc hl
_bms_skip_sp2:
    ld a, (hl)
    or a
    jr z, _bms_bad_args_pop         ; no address argument
    cp ' '
    jr nz, _bms_parse_addr
    inc hl
    jr _bms_skip_sp2
_bms_parse_addr:
    call hex_byte_val               ; A = addr high byte; HL advances 2
    ld d, a
    call hex_byte_val               ; A = addr low byte; HL advances 2
    ld e, a                         ; DE = source address
_bms_skip_sp3:
    ld a, (hl)
    or a
    jr z, _bms_bad_args_pop         ; no length argument
    cp ' '
    jr nz, _bms_parse_len
    inc hl
    jr _bms_skip_sp3
_bms_parse_len:
    call hex_byte_val               ; A = len high byte; HL advances 2
    ld b, a
    call hex_byte_val               ; A = len low byte; HL advances 2
    ld c, a                         ; BC = length; DE = source; stack: [FN]
    call bdfs_get_drive
    jr z, _bms_has_drive
    pop hl                          ; discard filename ptr
    ld hl, BDFS_NO_DRIVE_MSG
    call con_puts
    ret
_bms_has_drive:
    call bdfs_select_drive
    jr z, _bms_has_device
    pop hl                          ; discard filename ptr
    ld hl, _MSG_NO_DEVICE
    call con_puts
    ret
_bms_has_device:
    pop hl                          ; HL = filename ptr
    call bdfs_file_write            ; HL=filename, DE=source, BC=length; Z=ok NZ=error
    jr nz, _bms_write_error
    ld hl, _MSG_SAVED
    call con_puts                   ; "Saved "
    call _print_entry_name          ; print filename from BDFS_ENT_BUF
    ld a, CHAR_LF
    call con_putchar
    ret
_bms_write_error:
    call _error
    ret
_bms_bad_args_pop:
    pop hl                          ; discard filename ptr
    ld hl, _MSG_SAVE_USAGE
    call con_puts
    ret

; ---- _mon_dir ----------------------------------------------------------

; _mon_dir: list the current drive directory to the console
; in:  —
; out: — (errors are already printed)
; destroys: AF, BC, DE, HL
_mon_dir:
    call bdfs_get_drive
    jr nz, _bmd_no_drive
    call bdfs_select_drive
    jr z, _bmd_selected
    ld hl, _MSG_NO_DEVICE
    call con_puts
    ret
_bmd_no_drive:
    ld hl, BDFS_NO_DRIVE_MSG
    call con_puts
    ret
_bmd_selected:
    call bdfs_dir_open
    jr z, _bmd_opened
    call _error
    ret

_bmd_opened:
    ; HL = vol name ptr from bdfs_dir_open
    call _print_device_info         ; preserves HL
    call con_puts                   ; print volume name (HL still points to it)
    ld a, CHAR_LF
    call con_putchar

_bmd_scan:
    call bdfs_dir_next
    jr nz, _bmd_done                ; NZ = BDFS_ERR_END_OF_DIR, C = count
    ; Z = entry found; check flags for deleted status
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _bmd_deleted
    ; active entry
    ld hl, _MSG_INDENT
    call con_puts                   ; "  "
    call _print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bmd_scan

_bmd_deleted:
    ld hl, _MSG_DELETED
    call con_puts                   ; "  (deleted) "
    call _print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bmd_scan

_bmd_done:
    ld a, c
    call con_putchar_dec          ; C = active entry count from bdfs_dir_next
    ld hl, _MSG_FILES
    call con_puts                   ; " file(s)\n"
    ret

; ---- private helpers -------------------------------------------------------

; _print_entry_name: print 8.3 filename from BDFS_ENT_BUF (e.g. "HELLO.TXT")
; destroys: AF, BC, HL (saves/restores all)
_print_entry_name:
    push af
    push bc
    push hl
    ld hl, BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET
    ld b, BDFS_NAME_LEN
    call _print_entry_name_part
    ld a, (BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET)
    cp ' '                          ; ext field is space-padded: leading space means no extension
    jr z, _pen_done
    ld a, '.'
    call con_putchar
    ld hl, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN
    call _print_entry_name_part
_pen_done:
    pop hl
    pop bc
    pop af
    ret

; _print_entry_name_part: print at most B chars from (HL), stopping at first space (trims padding)
; in:  HL = source, B = max chars
; destroys: AF, BC, HL (saves/restores all)
_print_entry_name_part:
    push af
    push hl
    push bc
_penp_loop:
    ld a, b
    or a
    jr z, _penp_done
    ld a, (hl)
    cp ' '
    jr z, _penp_done
    call con_putchar
    inc hl
    dec b
    jr _penp_loop
_penp_done:
    pop bc
    pop hl
    pop af
    ret

; _print_device_info: print JEDEC ID, label, and capacity e.g. "ef4015 W25Q16 2MB\n"
; destroys: AF, BC, DE (saves/restores all; also preserves HL)
_print_device_info:
    push af
    push bc
    push de
    push hl
    call flash_get_device_id        ; A=mfr, B=type, C=cap
    call con_putchar_hex            ; print mfr
    ld a, b
    call con_putchar_hex            ; print type
    ld a, c
    call con_putchar_hex            ; print cap
    ld a, ' '
    call con_putchar
    call flash_get_device_name      ; HL = name string
    call con_puts
    ld a, ' '
    call con_putchar
    call flash_get_capacity_mb      ; A = MB
    call con_putchar_dec
    ld hl, _MSG_MB
    call con_puts
    pop hl
    pop de
    pop bc
    pop af
    ret

; _error: print error message for any BDFS_ERR_* code
; in:  A = BDFS_ERR_* code
; destroys: AF, BC, DE, HL
_error:
    cp BDFS_ERR_NO_DRIVE
    ld hl, BDFS_NO_DRIVE_MSG
    jr z, _bdfs_error_print
    cp BDFS_ERR_NO_DEVICE
    ld hl, _MSG_NO_DEVICE
    jr z, _bdfs_error_print
    cp BDFS_ERR_NOT_FORMATTED
    ld hl, _MSG_NOT_FORMATTED
    jr z, _bdfs_error_print
    cp BDFS_ERR_ERASE_FAIL
    ld hl, _MSG_ERASE_FAIL
    jr z, _bdfs_error_print
    cp BDFS_ERR_WRITE_FAIL
    ld hl, _MSG_WRITE_FAIL
    jr z, _bdfs_error_print
    cp BDFS_ERR_VERIFY_FAIL
    ld hl, _MSG_VERIFY_FAIL
    jr z, _bdfs_error_print
    cp BDFS_ERR_DIR_FULL
    ld hl, _MSG_DIR_FULL
    jr z, _bdfs_error_print
    cp BDFS_ERR_DISK_FULL
    ld hl, _MSG_DISK_FULL
    jr z, _bdfs_error_print
    ret                              ; END_OF_DIR and unknown: no message
_bdfs_error_print:
    call con_puts
    ret

; ---- strings ---------------------------------------------------------------

_MSG_FORMAT_CONF_PRE:   db "Format ", 0
_MSG_FORMAT_CONF_POST:  db "? y/n ", 0
_MSG_BAD_DRIVE:         db "Invalid drive", CHAR_LF, 0
_MSG_FORMAT_PRE:        db "Formatting drive ", 0
_MSG_FORMAT_OK:         db "Format ok - ", 0
_MSG_VERIFY_FAIL:       db "Verify fail", CHAR_LF, 0
_MSG_ERASE_FAIL:        db "Erase fail", CHAR_LF, 0
_MSG_WRITE_FAIL:        db "Write fail", CHAR_LF, 0
_MSG_INDENT:            db "  ", 0
_MSG_DELETED:           db "  (deleted) ", 0
_MSG_FILES:             db " file(s)", CHAR_LF, 0
_MSG_NOT_FORMATTED:     db "Not formatted", CHAR_LF, 0
_MSG_MB:                db "MB", CHAR_LF, 0
_MSG_NO_DEVICE:         db "No device in slot", CHAR_LF, 0
BDFS_NO_DRIVE_MSG:      db "No drive selected", CHAR_LF, 0
_MSG_SAVED:             db "Saved ", 0
_MSG_SAVE_USAGE:        db "s <name.ext> <addr> <len>", CHAR_LF, 0
_MSG_DIR_FULL:          db "Directory full", CHAR_LF, 0
_MSG_DISK_FULL:         db "Disk full", CHAR_LF, 0

    ENDIF
