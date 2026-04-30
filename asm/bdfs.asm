; bdfs.asm - BeanDeck File System monitor command implementations
;
; Drive selection: bdfs_set_drive / bdfs_get_drive map letters 'A'-'F' to slots 1-6.
; bdfs_format and bdfs_dir operate on the currently selected drive (BDFS_DRIVE must be set).

    INCLUDE "asm/chars.inc"
    INCLUDE "asm/bdfs.inc"

    PUBLIC bdfs_format
    PUBLIC bdfs_dir
    PUBLIC bdfs_set_drive
    PUBLIC bdfs_get_drive

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN flash_select_slot
    EXTERN flash_sector_erase
    EXTERN flash_page_program
    EXTERN flash_read
    EXTERN BDFS_HDR_BUF, BDFS_ENT_BUF, BDFS_SCAN_ADDR, BDFS_ACTIVE_COUNT, BDFS_DRIVE

; ---- bdfs_set_drive / bdfs_get_drive ---------------------------------------

; bdfs_set_drive: select active drive by letter and assert the corresponding flash slot
; in:  A = drive letter ('A'-'F')
; out: —
; destroys: AF
bdfs_set_drive:
    ld (BDFS_DRIVE), a
    sub 'A'
    inc a                           ; convert 'A'-'F' to slot 1-6
    jp flash_select_slot            ; tail call

; bdfs_get_drive: return the current drive letter
; in:  —
; out: A = drive letter ('A'-'F'), or 0 if no drive has been selected
; destroys: AF
bdfs_get_drive:
    ld a, (BDFS_DRIVE)
    ret

; ---- helpers ---------------------------------------------------------------

; _bdfs_check_drive: load BDFS_DRIVE and set Z if no drive is selected
; out: A = drive letter (NZ), or 0 (Z) if no drive selected
; destroys: AF
_bdfs_check_drive:
    ld a, (BDFS_DRIVE)
    or a
    ret

; _bdfs_print_trimmed: print at most B chars from (HL), stopping at first space (trims padding)
; in:  HL = source, B = max chars
; destroys: AF, B, HL
_bdfs_print_trimmed:
_bpt_loop:
    ld a, b
    or a
    ret z
    ld a, (hl)
    cp ' '
    ret z
    call con_putchar
    inc hl
    dec b
    jr _bpt_loop

; _bdfs_print_entry_name: print 8.3 filename from BDFS_ENT_BUF (e.g. "HELLO.TXT")
; destroys: AF, BC, HL
_bdfs_print_entry_name:
    ld hl, BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET
    ld b, BDFS_NAME_LEN
    call _bdfs_print_trimmed
    ld a, (BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET)
    cp ' '
    ret z
    ld a, '.'
    call con_putchar
    ld hl, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN
    call _bdfs_print_trimmed
    ret

; ---- bdfs_format -----------------------------------------------------------

; bdfs_format: erase sector 0 of the current drive and write a BDFS directory header
; in:  — (drive must be selected via bdfs_set_drive)
; out: —
; destroys: AF, BC, DE, HL
bdfs_format:
    call _bdfs_check_drive
    jp z, _bdfs_no_drive

    sub 'A'
    inc a                           ; slot 1-6
    call flash_select_slot

    ld hl, _bdfs_msg_fmt_pre
    call con_puts
    ld a, (BDFS_DRIVE)
    call con_putchar
    ld a, CHAR_LF
    call con_putchar

    ld h, 0x00                      ; addr[23:16]
    ld l, 0x00                      ; addr[15:8]
    call flash_sector_erase         ; Z=ok NZ=timeout
    jp nz, _bdfs_format_erase_fail

    ; build 16-byte header in BDFS_HDR_BUF: magic + vol_name + reserved
    ld hl, BDFS_HDR_BUF
    ld (hl), BDFS_MAGIC_0
    inc hl
    ld (hl), BDFS_MAGIC_1
    inc hl
    ; vol_name: "BDFSx" (5 chars) + 7 null bytes = 12 bytes total
    ld (hl), 'B'
    inc hl
    ld (hl), 'D'
    inc hl
    ld (hl), 'F'
    inc hl
    ld (hl), 'S'
    inc hl
    ld a, (BDFS_DRIVE)
    ld (hl), a
    inc hl
    ld b, 7
_bdfs_fmt_fill_vol:
    ld (hl), 0
    inc hl
    djnz _bdfs_fmt_fill_vol
    ; reserved: 2 bytes of 0
    ld (hl), 0
    inc hl
    ld (hl), 0

    ld hl, 0x0000                   ; addr[23:8]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_page_program         ; Z=ok NZ=timeout
    jp nz, _bdfs_format_write_fail

    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read

    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _bdfs_format_magic_fail
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, _bdfs_format_magic_fail

    ld hl, _bdfs_msg_fmt_ok
    call con_puts
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar
    ret

_bdfs_format_magic_fail:
    ld hl, _bdfs_msg_fmt_magic_fail
    call con_puts
    ret

_bdfs_format_erase_fail:
    ld hl, _bdfs_msg_fmt_erase_fail
    call con_puts
    ret

_bdfs_format_write_fail:
    ld hl, _bdfs_msg_fmt_write_fail
    call con_puts
    ret

; ---- bdfs_dir --------------------------------------------------------------

; bdfs_dir: read and display the BDFS directory for the current drive
; in:  — (drive must be selected via bdfs_set_drive)
; out: —
; destroys: AF, BC, DE, HL
bdfs_dir:
    call _bdfs_check_drive
    jp z, _bdfs_no_drive

    sub 'A'
    inc a                           ; slot 1-6
    call flash_select_slot

    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read

    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _bdfs_dir_not_formatted
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, _bdfs_dir_not_formatted

    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar

    xor a
    ld (BDFS_ACTIVE_COUNT), a
    ld hl, BDFS_HDR_SIZE
    ld (BDFS_SCAN_ADDR), hl

_bdfs_dir_scan:
    xor a                           ; addr[23:16] = 0x00
    ld hl, (BDFS_SCAN_ADDR)         ; addr[15:0]
    ld de, BDFS_ENT_BUF
    ld bc, BDFS_ENT_SIZE
    call flash_read

    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET)
    cp BDFS_ENT_EMPTY
    jr z, _bdfs_dir_done

    ld hl, (BDFS_SCAN_ADDR)
    ld bc, BDFS_ENT_SIZE
    add hl, bc
    ld (BDFS_SCAN_ADDR), hl

    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _bdfs_dir_deleted

    ld a, (BDFS_ACTIVE_COUNT)
    inc a
    ld (BDFS_ACTIVE_COUNT), a
    ld hl, _bdfs_msg_indent
    call con_puts
    call _bdfs_print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bdfs_dir_scan

_bdfs_dir_deleted:
    ld hl, _bdfs_msg_deleted
    call con_puts
    call _bdfs_print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bdfs_dir_scan

_bdfs_dir_done:
    ld a, (BDFS_ACTIVE_COUNT)
    add a, '0'
    call con_putchar
    ld hl, _bdfs_msg_files
    call con_puts
    ret

_bdfs_dir_not_formatted:
    ld hl, _bdfs_msg_not_formatted
    call con_puts
    ret

; ---- shared error handlers -------------------------------------------------

_bdfs_no_drive:
    ld hl, _bdfs_msg_no_drive
    jp con_puts                     ; tail call

; ---- strings ---------------------------------------------------------------

_bdfs_msg_fmt_pre:          db "Formatting drive ", 0
_bdfs_msg_fmt_ok:           db "Format ok ", 0
_bdfs_msg_fmt_magic_fail:   db "Format fail (bad magic)", CHAR_LF, 0
_bdfs_msg_fmt_erase_fail:   db "Format fail (erase timeout)", CHAR_LF, 0
_bdfs_msg_fmt_write_fail:   db "Format fail (write timeout)", CHAR_LF, 0
_bdfs_msg_indent:           db "  ", 0
_bdfs_msg_deleted:          db "  (deleted) ", 0
_bdfs_msg_files:            db " file(s)", CHAR_LF, 0
_bdfs_msg_not_formatted:    db "Not formatted", CHAR_LF, 0
_bdfs_msg_no_drive:         db "No drive selected", CHAR_LF, 0
