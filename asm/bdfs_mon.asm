; bdfs_mon.asm - BDFS monitor presentation layer
;
; Wraps bdfs.asm pure functions with console output for the monitor.
; _cmd_format and _cmd_dir in monitor.asm call bdfs_mon_format / bdfs_mon_dir.

    IFDEF INCLUDE_BDFS

    INCLUDE "asm/chars.inc"
    INCLUDE "asm/bdfs.inc"
    INCLUDE "asm/drivers/w25q.inc"

    PUBLIC bdfs_mon_format
    PUBLIC bdfs_mon_dir
    PUBLIC BDFS_NO_DRIVE_MSG

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN con_putchar_hex
    EXTERN con_putchar_dec
    EXTERN bdfs_format
    EXTERN bdfs_dir_open
    EXTERN bdfs_dir_next
    EXTERN bdfs_get_drive
    EXTERN BDFS_DRIVE
    EXTERN BDFS_HDR_BUF
    EXTERN BDFS_ENT_BUF
    EXTERN flash_select_slot
    EXTERN flash_has_device
    EXTERN flash_get_device_id
    EXTERN W25Q80_NAME
    EXTERN W25Q16_NAME
    EXTERN W25Q32_NAME
    EXTERN W25Q64_NAME
    EXTERN W25Q128_NAME

; ---- bdfs_mon_format -------------------------------------------------------

; bdfs_mon_format: format the current drive with console feedback
; in:  HL = volume name string (null-terminated, max 11 chars), or 0 for default
; out: Z=ok, NZ=error (A=BDFS_ERR_*; errors are already printed)
; destroys: AF, BC, DE, HL
bdfs_mon_format:
    push hl                         ; save vol name ptr

    call bdfs_get_drive
    jr nz, _bfm_got_drive
    pop hl                          ; discard vol name ptr
    ld hl, BDFS_NO_DRIVE_MSG
    call con_puts
    ld a, BDFS_ERR_NO_DRIVE
    or a
    ret

_bfm_got_drive:
    ; check for device before printing header, to match original output ordering:
    ; no-device shows "No device in slot" without the "Formatting drive X" header
    sub 'A'-1
    call flash_select_slot
    call flash_has_device
    jr z, _bfm_has_device
    pop hl                          ; discard vol name ptr
    ld hl, _msg_no_device
    call con_puts
    ld a, BDFS_ERR_NO_DEVICE
    or a
    ret

_bfm_has_device:
    ld hl, _msg_fmt_pre
    call con_puts                   ; "Formatting drive "
    ld a, (BDFS_DRIVE)
    call con_putchar
    ld a, CHAR_LF
    call con_putchar
    call _print_device_info         ; preserves HL
    pop hl                          ; restore vol name ptr
    call bdfs_format
    jr nz, _bfm_error
    ; success: "Format ok - <volname>\n"
    ld hl, _msg_fmt_ok
    call con_puts
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar
    xor a                           ; Z
    ret

_bfm_error:
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
    ; look up label — ld hl does not affect flags so jr z still acts on the preceding cp
    ld a, c
    cp W25Q_CAP_16MBIT
    ld hl, W25Q16_NAME
    jr z, _pdi_print_label
    cp W25Q_CAP_32MBIT
    ld hl, W25Q32_NAME
    jr z, _pdi_print_label
    cp W25Q_CAP_64MBIT
    ld hl, W25Q64_NAME
    jr z, _pdi_print_label
    cp W25Q_CAP_128MBIT
    ld hl, W25Q128_NAME
    jr z, _pdi_print_label
    cp W25Q_CAP_8MBIT
    ld hl, W25Q80_NAME
    jr z, _pdi_print_label
    ld hl, _msg_unknown_device
_pdi_print_label:
    call con_puts                   ; BC preserved via con_putchar; C=cap still valid
    ld a, ' '
    call con_putchar
    ; capacity in MB: 1 << (cap - W25Q_CAP_8MBIT)
    ld a, c
    sub W25Q_CAP_8MBIT              ; A = shift count (0=1MB, 1=2MB, ...)
    ld b, a
    ld a, 1
_pdi_shift:
    dec b
    jp m, _pdi_print_mb
    rlca
    jr _pdi_shift
_pdi_print_mb:
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
    jr z, _ferr_print
    cp BDFS_ERR_ERASE_FAIL
    ld hl, _msg_fmt_erase_fail
    jr z, _ferr_print
    cp BDFS_ERR_WRITE_FAIL
    ld hl, _msg_fmt_write_fail
    jr z, _ferr_print
    ret                             ; no message for other codes (NO_DRIVE/NO_DEVICE handled by caller)
_ferr_print:
    call con_puts
    ret

; _dir_error: print error message for a bdfs_dir_open failure
; in:  A = BDFS_ERR_* code
; destroys: AF, BC, DE, HL
_dir_error:
    cp BDFS_ERR_NO_DRIVE
    ld hl, BDFS_NO_DRIVE_MSG
    jr z, _derr_print
    cp BDFS_ERR_NOT_FORMATTED
    ld hl, _msg_not_formatted
    jr z, _derr_print
    ld hl, _msg_no_device           ; default: BDFS_ERR_NO_DEVICE
_derr_print:
    call con_puts
    ret

; ---- strings ---------------------------------------------------------------

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
_msg_unknown_device:    db "unknown", 0
_msg_no_device:         db "No device in slot", CHAR_LF, 0
BDFS_NO_DRIVE_MSG:      db "No drive selected", CHAR_LF, 0

    ENDIF
