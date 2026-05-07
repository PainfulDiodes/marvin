; bdfs.asm - BeanDeck File System
;
; Drive selection: bdfs_set_drive / bdfs_get_drive, letters 'A'-'F' mapped to slots 1-6.
; bdfs_format and bdfs_dir operate on the currently selected drive (BDFS_DRIVE must be set).

    INCLUDE "asm/chars.inc"
    INCLUDE "asm/drivers/w25q.inc"

; ---- flash directory format constants ------------------------------------

BDFS_MAGIC_0          EQU 0xBD
BDFS_MAGIC_1          EQU 0x01
BDFS_DIR_SECTOR       EQU 0x0000
BDFS_DATA_START       EQU 0x0001

BDFS_FLAG_ACTIVE      EQU 0x00
BDFS_FLAG_DELETED_BIT EQU 0

BDFS_ENT_EMPTY        EQU 0xFF    ; name[0] value meaning no more entries - erase sets all bytes to FF

BDFS_NAME_LEN         EQU 8
BDFS_EXT_LEN          EQU 3
BDFS_VOL_NAME_LEN     EQU 12

    PUBLIC bdfs_format
    PUBLIC bdfs_dir
    PUBLIC bdfs_set_drive
    PUBLIC bdfs_get_drive
    PUBLIC BDFS_RAMSIZE
    PUBLIC BDFS_DRIVE
    PUBLIC BDFS_NO_DRIVE_MSG

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN con_putchar_hex
    EXTERN flash_select_slot
    EXTERN flash_has_device
    EXTERN flash_get_device_id
    EXTERN W25Q80_NAME
    EXTERN W25Q16_NAME
    EXTERN W25Q32_NAME
    EXTERN W25Q64_NAME
    EXTERN W25Q128_NAME
    EXTERN flash_sector_erase
    EXTERN flash_page_program
    EXTERN flash_read
    EXTERN BDFS_RAMSTART

; ---- RAM layout (private to this module) ------------------------------------

BDFS_HDR_BUF            EQU BDFS_RAMSTART                          ; directory header r/w buffer
BDFS_HDR_SIZE           EQU 16
BDFS_ENT_BUF            EQU BDFS_HDR_BUF + BDFS_HDR_SIZE           ; entry scan buffer
BDFS_ENT_SIZE           EQU 17

BDFS_TMP                EQU BDFS_ENT_BUF + BDFS_ENT_SIZE           ; scratch variable
BDFS_TMP_LEN            EQU 2
BDFS_ACTIVE_COUNT       EQU BDFS_TMP + BDFS_TMP_LEN                ; active entry count
BDFS_ACTIVE_COUNT_LEN   EQU 1
BDFS_DRIVE              EQU BDFS_ACTIVE_COUNT + BDFS_ACTIVE_COUNT_LEN ; active drive letter ('A'-'F', 0=none)
BDFS_DRIVE_LEN          EQU 1
BDFS_RAMSIZE            EQU BDFS_HDR_SIZE + BDFS_ENT_SIZE + BDFS_TMP_LEN + BDFS_ACTIVE_COUNT_LEN + BDFS_DRIVE_LEN

; Header offsets
BDFS_HDR_MAGIC_OFFSET        EQU 0       ; 2 bytes
BDFS_HDR_VOL_NAME_OFFSET     EQU 2       ; 12 bytes
BDFS_HDR_RESERVED_OFFSET     EQU 14      ; 2 bytes

; Entry offsets (8.3 filename: separate name and ext fields, space-padded, no dot stored)
BDFS_ENT_NAME_OFFSET         EQU 0       ; 8 bytes, space-padded uppercase basename
BDFS_ENT_EXT_OFFSET          EQU 8       ; 3 bytes, space-padded uppercase extension
BDFS_ENT_SECTOR_OFFSET       EQU 11      ; 2 bytes, little-endian
BDFS_ENT_LENGTH_OFFSET       EQU 13      ; 3 bytes, little-endian
BDFS_ENT_FLAGS_OFFSET        EQU 16      ; 1 byte

; ---- bdfs_set_drive / bdfs_get_drive ---------------------------------------

; bdfs_set_drive: record the active drive letter
; NOTE: it is not possible to persistently set the slot - as SPI may also used for 
; other purposes - so we set the logical current drive this in RAM and set the slot 
; immediately prior to (and for the duration of) reading/writing to a drive
; in:  A = drive letter ('A'-'F')
; out: —
; destroys: -
bdfs_set_drive:
    ld (BDFS_DRIVE), a
    ret

; bdfs_get_drive: return the current drive letter
; in:  —
; out: A = drive letter ('A'-'F'), or 0 if no drive has been selected (Z/NZ flag is set accordingly)
; destroys: AF
bdfs_get_drive:
    ld a, (BDFS_DRIVE)
    or a
    ret

; ---- helpers ---------------------------------------------------------------

; _bdfs_con_print_entry_name: print 8.3 filename from BDFS_ENT_BUF (e.g. "HELLO.TXT")
; destroys: —
_bdfs_con_print_entry_name:
    push af
    push bc
    push hl
    ld hl, BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET
    ld b, BDFS_NAME_LEN
    call _bdfs_con_print_entry_name_part
    ld a, (BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET)
    cp ' ' ; ext field is space-padded: leading space means no extension
    jr z, _bcpen_done
    ld a, '.'
    call con_putchar
    ld hl, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN
    call _bdfs_con_print_entry_name_part
_bcpen_done:
    pop hl
    pop bc
    pop af
    ret

; _bdfs_con_print_entry_name_part: print at most B chars from (HL), stopping at first space (trims padding)
; in:  HL = source, B = max chars
; destroys: —
_bdfs_con_print_entry_name_part:
    push af
    push hl
    push bc
_bcpenp_loop:
    ld a, b
    or a
    jr z, _bcpenp_done
    ld a, (hl)
    cp ' '
    jr z, _bcpenp_done
    call con_putchar
    inc hl
    dec b
    jr _bcpenp_loop
_bcpenp_done:
    pop bc
    pop hl
    pop af
    ret

; _bdfs_print_decimal: print byte in A as decimal (0-255)
; TODO this should be moved into a more central location so is available elsewhere
_bdfs_print_decimal:
    push af
    push bc
    ld b, 0                     ; hundreds
    ld c, 0                     ; tens
_bpd_hundreds:
    cp 100
    jr c, _bpd_tens
    sub 100
    inc b
    jr _bpd_hundreds
_bpd_tens:
    cp 10
    jr c, _bpd_units
    sub 10
    inc c
    jr _bpd_tens
_bpd_units:
    push af                     ; save units digit
    ld a, b
    or a
    jr z, _bpd_no_hundreds
    add a, '0'
    call con_putchar            ; print hundreds
    ld a, c
    add a, '0'
    call con_putchar            ; print tens (always if hundreds printed)
    jr _bpd_print_units
_bpd_no_hundreds:
    ld a, c
    or a
    jr z, _bpd_print_units
    add a, '0'
    call con_putchar            ; print tens
_bpd_print_units:
    pop af
    add a, '0'
    call con_putchar            ; print units
    pop bc
    pop af
    ret

; ---- bdfs_format -----------------------------------------------------------

; bdfs_format: erase sector 0 of the current drive and write a BDFS directory header
; in:  HL = volume name string (null-terminated, max BDFS_VOL_NAME_LEN-1 chars), or 0 for default
; out: —
; destroys: —
bdfs_format:
    call bdfs_get_drive
    jp z, _bdfs_no_drive            ; tail call: common error handler

    push af
    push bc
    push de
    push hl

    ld (BDFS_TMP), hl               ; stash name ptr across erase
    sub 'A'-1                       ; slot 1-6
    call flash_select_slot
    call flash_has_device
    jp nz, _bdfs_no_device_exit

    ld hl, _BDFS_MSG_FMT_PRE
    call con_puts
    ld a, (BDFS_DRIVE)
    call con_putchar
    ld a, CHAR_LF
    call con_putchar
    call _bdfs_print_device_info

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
    ex de, hl                       ; DE = vol_name field ptr
    ld hl, (BDFS_TMP)               ; HL = name pointer or 0
    ld a, h
    or l
    jr z, _bdfs_fmt_default_name
    ; custom name: copy up to BDFS_VOL_NAME_LEN chars, ensure null-terminated
    ld b, BDFS_VOL_NAME_LEN
_bdfs_fmt_copy_name:
    ld a, (hl)
    or a
    jr z, _bdfs_fmt_null_fill       ; end of source: null-fill remaining
    ld (de), a
    inc hl
    inc de
    djnz _bdfs_fmt_copy_name
    ; wrote full BDFS_VOL_NAME_LEN chars: overwrite last with null terminator
    dec de
    xor a
    ld (de), a
    inc de
    jr _bdfs_fmt_reserved
_bdfs_fmt_null_fill:
    xor a
_bdfs_fmt_null_loop:
    ld (de), a
    inc de
    djnz _bdfs_fmt_null_loop
    jr _bdfs_fmt_reserved
_bdfs_fmt_default_name:
    ld hl, _BDFS_DEFAULT_PREFIX
    ld bc, _BDFS_DEFAULT_PREFIX_LEN
    ldir                            ; copy "BDFS", DE now points past it
    ld a, (BDFS_DRIVE)
    ld (de), a
    inc de
    ld b, BDFS_VOL_NAME_LEN - _BDFS_DEFAULT_PREFIX_LEN - 1   ; remaining space, 1 for the drive letter
_bdfs_fmt_fill_default:
    xor a
    ld (de), a
    inc de
    djnz _bdfs_fmt_fill_default
_bdfs_fmt_reserved:
    xor a
    ld (de), a
    inc de
    ld (de), a
    ; write the buffer to flash
    ld hl, 0x0000                   ; addr[23:8]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_page_program         ; Z=ok NZ=timeout
    jp nz, _bdfs_format_write_fail
    ; read back to buffer
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ; verify
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _bdfs_format_magic_fail
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, _bdfs_format_magic_fail
    ; format OK
    ld hl, _BDFS_MSG_FMT_OK
    call con_puts
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar
    jr _bdfs_format_exit

_bdfs_format_magic_fail:
    ld hl, _BDFS_MSG_FMT_MAGIC_FAIL
    call con_puts
    jr _bdfs_format_exit

_bdfs_format_erase_fail:
    ld hl, _BDFS_MSG_FMT_ERASE_FAIL
    call con_puts
    jr _bdfs_format_exit

_bdfs_format_write_fail:
    ld hl, _BDFS_MSG_FMT_WRITE_FAIL
    call con_puts

_bdfs_format_exit:
    pop hl
    pop de
    pop bc
    pop af
    ret

; ---- bdfs_dir --------------------------------------------------------------

; bdfs_dir: read and display the BDFS directory for the current drive
; in:  — (drive must be selected via bdfs_set_drive)
; out: —
; destroys: —
bdfs_dir:
    call bdfs_get_drive
    jp z, _bdfs_no_drive            ; tail call: common error handler

    push af
    push bc
    push de
    push hl

    sub 'A'-1                       ; slot 1-6
    call flash_select_slot
    call flash_has_device
    jp nz, _bdfs_no_device_exit

    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ; is formatted?
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _bdfs_dir_not_formatted
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, _bdfs_dir_not_formatted
    ; print device info and volume name
    call _bdfs_print_device_info
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar

    xor a
    ld (BDFS_ACTIVE_COUNT), a   ; reset count of active entries

    ld hl, BDFS_HDR_SIZE
    ld (BDFS_TMP), hl

_bdfs_dir_scan:
    xor a                     ; addr[23:16] = 0x00
    ld hl, (BDFS_TMP)         ; addr[15:0]
    ld de, BDFS_ENT_BUF
    ld bc, BDFS_ENT_SIZE
    call flash_read

    ; empty entry?
    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET)
    cp BDFS_ENT_EMPTY
    jr z, _bdfs_dir_done
    
    ; advance pointer to next entry
    ld hl, (BDFS_TMP)
    ld bc, BDFS_ENT_SIZE
    add hl, bc
    ld (BDFS_TMP), hl

    ; check flags
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _bdfs_dir_deleted

    ; process entry
    ; increment count
    ld a, (BDFS_ACTIVE_COUNT)
    inc a
    ld (BDFS_ACTIVE_COUNT), a
    ; print entry
    ld hl, _BDFS_MSG_INDENT
    call con_puts
    call _bdfs_con_print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bdfs_dir_scan

_bdfs_dir_deleted:
    ld hl, _BDFS_MSG_DELETED
    call con_puts
    call _bdfs_con_print_entry_name
    ld a, CHAR_LF
    call con_putchar
    jr _bdfs_dir_scan

_bdfs_dir_done:
    ld a, (BDFS_ACTIVE_COUNT)
    call _bdfs_print_decimal
    ld hl, _BDFS_MSG_FILES
    call con_puts
    pop hl
    pop de
    pop bc
    pop af
    ret

_bdfs_dir_not_formatted:
    ld hl, _BDFS_MSG_NOT_FORMATTED
    call con_puts
    pop hl
    pop de
    pop bc
    pop af
    ret

; ---- helpers ---------------------------------------------------------------

; _bdfs_print_device_info: print JEDEC ID, label, and capacity e.g. "ef4015 W25Q16 2MB\n"
; destroys: HL
_bdfs_print_device_info:
    push af
    push bc
    push de
    call flash_get_device_id        ; A=mfr, B=type, C=cap (BC preserved by con_putchar_hex)
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
    jr z, _bpdi_print_label
    cp W25Q_CAP_32MBIT
    ld hl, W25Q32_NAME
    jr z, _bpdi_print_label
    cp W25Q_CAP_64MBIT
    ld hl, W25Q64_NAME
    jr z, _bpdi_print_label
    cp W25Q_CAP_128MBIT
    ld hl, W25Q128_NAME
    jr z, _bpdi_print_label
    cp W25Q_CAP_8MBIT
    ld hl, W25Q80_NAME
    jr z, _bpdi_print_label
    ld hl, _BDFS_MSG_UNKNOWN_DEVICE
_bpdi_print_label:
    call con_puts                   ; BC preserved via con_putchar; C=cap still valid
    ld a, ' '
    call con_putchar
    ; capacity in MB: 1 << (cap - W25Q_CAP_8MBIT)
    ld a, c
    sub W25Q_CAP_8MBIT              ; A = shift count (0=1MB, 1=2MB, ...)
    ld b, a
    ld a, 1
_bpdi_shift:
    dec b
    jp m, _bpdi_print_mb
    rlca
    jr _bpdi_shift
_bpdi_print_mb:
    call _bdfs_print_decimal
    ld hl, _BDFS_MSG_MB
    call con_puts
    pop de
    pop bc
    pop af
    ret

; ---- shared error handlers -------------------------------------------------

_bdfs_no_device_exit:
    pop hl
    pop de
    pop bc
    pop af
    ld hl, _BDFS_MSG_NO_DEVICE
    call con_puts
    ret

_bdfs_no_drive:
    ld hl, BDFS_NO_DRIVE_MSG
    call con_puts
    ret

; ---- strings ---------------------------------------------------------------

_BDFS_DEFAULT_PREFIX:       db "BDFS-"
_BDFS_DEFAULT_PREFIX_LEN    equ $ - _BDFS_DEFAULT_PREFIX
_BDFS_MSG_FMT_PRE:          db "Formatting drive ", 0
_BDFS_MSG_FMT_OK:           db "Format ok - ", 0
_BDFS_MSG_FMT_MAGIC_FAIL:   db "Format fail (bad magic)", CHAR_LF, 0
_BDFS_MSG_FMT_ERASE_FAIL:   db "Format fail (erase timeout)", CHAR_LF, 0
_BDFS_MSG_FMT_WRITE_FAIL:   db "Format fail (write timeout)", CHAR_LF, 0
_BDFS_MSG_INDENT:           db "  ", 0
_BDFS_MSG_DELETED:          db "  (deleted) ", 0
_BDFS_MSG_FILES:            db " file(s)", CHAR_LF, 0
_BDFS_MSG_NOT_FORMATTED:    db "Not formatted", CHAR_LF, 0
_BDFS_MSG_MB:               db "MB", CHAR_LF, 0
_BDFS_MSG_UNKNOWN_DEVICE:   db "unknown", 0
_BDFS_MSG_NO_DEVICE:        db "No device in slot", CHAR_LF, 0
BDFS_NO_DRIVE_MSG:          db "No drive selected", CHAR_LF, 0
