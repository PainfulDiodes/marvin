; bdfs_mon.asm - BDFS monitor presentation layer
;
; Wraps bdfs.asm pure functions with console output for the monitor.
; Command handlers (bdfs_mon_cmd_*) are called from monitor.asm dispatch stubs.

    IFDEF INCLUDE_BDFS

    INCLUDE "asm/chars.inc"
    INCLUDE "asm/bdfs.inc"

    PUBLIC bdfs_mon_cmd_format
    PUBLIC bdfs_mon_cmd_dir
    PUBLIC bdfs_mon_cmd_drive
    PUBLIC bdfs_mon_format
    PUBLIC bdfs_mon_dir
    PUBLIC BDFS_NO_DRIVE_MSG

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN con_putchar_hex
    EXTERN con_putchar_dec
    EXTERN bdfs_get_device
    EXTERN bdfs_format
    EXTERN bdfs_dir_open
    EXTERN bdfs_dir_next
    EXTERN bdfs_get_drive
    EXTERN bdfs_set_drive
    EXTERN BDFS_DRIVE
    EXTERN BDFS_HDR_BUF
    EXTERN BDFS_ENT_BUF
    EXTERN flash_get_device_id
    EXTERN flash_get_device_name
    EXTERN flash_get_capacity_mb

; ---- monitor command handlers ----------------------------------------------

; bdfs_mon_cmd_format: 'f' command — confirm and format the current drive
; in:  HL = pointer into CMD_BUFFER past 'f' (optional volume name arg follows)
; out: — (all output already printed)
; destroys: AF, BC, DE, HL
bdfs_mon_cmd_format:
_bmcf_skip_sp:
    ld a, (hl)
    cp ' '
    jr nz, _bmcf_got_arg
    inc hl
    jr _bmcf_skip_sp
_bmcf_got_arg:
    push hl                          ; save name pointer

    call bdfs_get_drive
    jr z, _bmcf_confirm
    pop hl                           ; discard name ptr
    ld hl, BDFS_NO_DRIVE_MSG
    call con_puts
    ret

_bmcf_confirm:
    ld b, a                          ; save drive letter
    ld hl, _msg_fmt_confirm_pre
    call con_puts                    ; "Format "
    ld a, b
    call con_putchar                 ; drive letter
    ld hl, _msg_fmt_confirm_post
    call con_puts                    ; "? y/n "
    call con_getchar
    ld b, a                          ; save response before echo clobbers A
    call con_putchar                 ; echo
    ld a, CHAR_LF
    call con_putchar
    ld a, b
    cp 'y'
    jr z, _bmcf_confirmed
    pop hl                           ; discard name ptr: user declined
    ret

_bmcf_confirmed:
    pop hl                           ; restore name pointer
    ld a, (hl)
    or a
    jr nz, _bmcf_run
    ld hl, 0                         ; no name arg: use default
_bmcf_run:
    call bdfs_mon_format
    ret

; bdfs_mon_cmd_dir: 'd' command — list current drive directory
; in:  —
; out: — (all output already printed)
; destroys: AF, BC, DE, HL
bdfs_mon_cmd_dir:
    call bdfs_mon_dir
    ret

; bdfs_mon_cmd_drive: '@' command — select drive A-F
; in:  HL = pointer to drive letter char in CMD_BUFFER
; out: — (error message printed on invalid input)
; destroys: AF
bdfs_mon_cmd_drive:
    ld a, (hl)
    and 0dfh                         ; fold lowercase to uppercase
    cp 'A'
    jr c, _bmcd_bad
    cp 'G'
    jr nc, _bmcd_bad
    call bdfs_set_drive
    ret

_bmcd_bad:
    ld hl, _msg_bad_drive
    call con_puts
    ret

; ---- bdfs_mon_format -------------------------------------------------------

; bdfs_mon_format: format the current drive with console feedback
; in:  HL = volume name string (null-terminated, max 11 chars), or 0 for default
; out: Z=ok, NZ=error (A=BDFS_ERR_*; errors are already printed)
; destroys: AF, BC, DE, HL
bdfs_mon_format:
    push hl                         ; save vol name ptr
    call bdfs_get_drive
    jr nz, _bmf_no_drive
    call bdfs_get_device
    jr z, _bmf_has_device
    pop hl                          ; discard vol name ptr
    ld hl, _msg_no_device
    call con_puts
    or a                            ; NZ (A = BDFS_ERR_NO_DEVICE)
    ret
_bmf_no_drive:
    pop hl                          ; discard vol name ptr
    ld hl, BDFS_NO_DRIVE_MSG
    call con_puts
    or a                            ; NZ (A = BDFS_ERR_NO_DRIVE)
    ret

_bmf_has_device:
    ld hl, _msg_fmt_pre
    call con_puts                   ; "Formatting drive "
    ld a, (BDFS_DRIVE)
    call con_putchar
    ld a, CHAR_LF
    call con_putchar
    call _print_device_info         ; preserves HL
    pop hl                          ; restore vol name ptr
    call bdfs_format
    jr nz, _bmf_error
    ; success: "Format ok - <volname>\n"
    ld hl, _msg_fmt_ok
    call con_puts
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar
    xor a                           ; Z
    ret

_bmf_error:
    ld b, a                         ; save error code across _format_error call
    call _format_error
    ld a, b
    or a                            ; NZ (all error codes are non-zero)
    ret

; ---- bdfs_mon_dir ----------------------------------------------------------

; bdfs_mon_dir: list the current drive directory to the console
; in:  —
; out: — (errors are already printed)
; destroys: AF, BC, DE, HL
bdfs_mon_dir:
    call bdfs_dir_open
    jr z, _bmd_opened
    call _dir_error
    ret

_bmd_opened:
    ; HL = vol name ptr from bdfs_dir_open; slot still selected from that call
    call _print_device_info         ; preserves HL
    call con_puts                   ; print volume name (HL still points to it)
    ld a, CHAR_LF
    call con_putchar

_bmd_scan:
    call bdfs_dir_next
    jr nz, _bmd_done                ; NZ = no more entries, A = count
    ; Z = entry found; check flags for deleted status
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _bmd_deleted
    ; active entry
    ld hl, _msg_indent
    call con_puts                   ; "  "
    call _print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bmd_scan

_bmd_deleted:
    ld hl, _msg_deleted
    call con_puts                   ; "  (deleted) "
    call _print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bmd_scan

_bmd_done:
    call con_putchar_dec          ; A = active entry count
    ld hl, _msg_files
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
    ld hl, _msg_mb
    call con_puts
    pop hl
    pop de
    pop bc
    pop af
    ret

; _format_error: print error message for a bdfs_format failure
; in:  A = BDFS_ERR_* code
; destroys: AF, BC, DE, HL
_format_error:
    cp BDFS_ERR_VERIFY_FAIL
    ld hl, _msg_fmt_magic_fail
    jr z, _fe_print
    cp BDFS_ERR_ERASE_FAIL
    ld hl, _msg_fmt_erase_fail
    jr z, _fe_print
    cp BDFS_ERR_WRITE_FAIL
    ld hl, _msg_fmt_write_fail
    jr z, _fe_print
    ret                             ; no message for other codes (NO_DRIVE/NO_DEVICE handled by caller)
_fe_print:
    call con_puts
    ret

; _dir_error: print error message for a bdfs_dir_open failure
; in:  A = BDFS_ERR_* code
; destroys: AF, BC, DE, HL
_dir_error:
    cp BDFS_ERR_NO_DRIVE
    ld hl, BDFS_NO_DRIVE_MSG
    jr z, _de_print
    cp BDFS_ERR_NOT_FORMATTED
    ld hl, _msg_not_formatted
    jr z, _de_print
    ld hl, _msg_no_device           ; default: BDFS_ERR_NO_DEVICE
_de_print:
    call con_puts
    ret

; ---- strings ---------------------------------------------------------------

_msg_fmt_confirm_pre:   db "Format ", 0
_msg_fmt_confirm_post:  db "? y/n ", 0
_msg_bad_drive:         db "Invalid drive", CHAR_LF, 0
_msg_fmt_pre:           db "Formatting drive ", 0
_msg_fmt_ok:            db "Format ok - ", 0
_msg_fmt_magic_fail:    db "Format fail (bad magic)", CHAR_LF, 0
_msg_fmt_erase_fail:    db "Format fail (erase timeout)", CHAR_LF, 0
_msg_fmt_write_fail:    db "Format fail (write timeout)", CHAR_LF, 0
_msg_indent:            db "  ", 0
_msg_deleted:           db "  (deleted) ", 0
_msg_files:             db " file(s)", CHAR_LF, 0
_msg_not_formatted:     db "Not formatted", CHAR_LF, 0
_msg_mb:                db "MB", CHAR_LF, 0
_msg_no_device:         db "No device in slot", CHAR_LF, 0
BDFS_NO_DRIVE_MSG:      db "No drive selected", CHAR_LF, 0

    ENDIF
