; bdfs.asm - BeanDeck File System (pure data/operation layer)
;
; bdfs_init: initialise RAM state; call once at startup.
; Drive selection: bdfs_set_drive / bdfs_get_drive, letters 'A'-'F' mapped to slots 1-6.
; bdfs_has_device: check whether a device is present on the current drive's slot.
; bdfs_format: erase and write header; returns Z=ok, NZ=error (A=BDFS_ERR_*).
; bdfs_dir_open / bdfs_dir_next: iterator for directory entries (no output).

    INCLUDE "asm/bdfs.inc"

    PUBLIC bdfs_init
    PUBLIC bdfs_has_device
    PUBLIC bdfs_format
    PUBLIC bdfs_dir_open
    PUBLIC bdfs_dir_next
    PUBLIC bdfs_set_drive
    PUBLIC bdfs_get_drive
    PUBLIC BDFS_RAMSIZE
    PUBLIC BDFS_DRIVE
    PUBLIC BDFS_HDR_BUF
    PUBLIC BDFS_ENT_BUF

    EXTERN flash_select_slot
    EXTERN flash_has_device
    EXTERN flash_sector_erase
    EXTERN flash_page_program
    EXTERN flash_read
    EXTERN BDFS_RAMSTART

; ---- RAM layout (private to this module) ------------------------------------

BDFS_HDR_BUF            EQU BDFS_RAMSTART                            ; directory header r/w buffer
BDFS_ENT_BUF            EQU BDFS_HDR_BUF + BDFS_HDR_SIZE            ; entry scan buffer
BDFS_TMP                EQU BDFS_ENT_BUF + BDFS_ENT_SIZE            ; scratch variable (2 bytes)
BDFS_TMP_LEN            EQU 2
BDFS_ACTIVE_COUNT       EQU BDFS_TMP + BDFS_TMP_LEN                 ; active entry count (1 byte)
BDFS_ACTIVE_COUNT_LEN   EQU 1
BDFS_DRIVE              EQU BDFS_ACTIVE_COUNT + BDFS_ACTIVE_COUNT_LEN ; active drive letter ('A'-'F', 0=none)
BDFS_DRIVE_LEN          EQU 1
BDFS_RAMSIZE            EQU BDFS_HDR_SIZE + BDFS_ENT_SIZE + BDFS_TMP_LEN + BDFS_ACTIVE_COUNT_LEN + BDFS_DRIVE_LEN

; ---- bdfs_init / bdfs_set_drive / bdfs_get_drive ---------------------------

; bdfs_init: initialise BDFS RAM state; call once at system startup
; in:  —
; out: —
; destroys: AF
bdfs_init:
    xor a
    ld (BDFS_DRIVE), a
    ret

; bdfs_set_drive: record the active drive letter
; NOTE: it is not possible to persistently set the slot - as SPI may also be used for
; other purposes - so we set the logical current drive in RAM and set the slot
; immediately prior to (and for the duration of) reading/writing to a drive
; in:  A = drive letter ('A'-'F')
; out: —
; destroys: -
bdfs_set_drive:
    ld (BDFS_DRIVE), a
    ret

; bdfs_get_drive: return the current drive letter
; in:  —
; out: A = drive letter ('A'-'F'), or 0 if no drive has been selected (Z/NZ flag set accordingly)
; destroys: AF
bdfs_get_drive:
    ld a, (BDFS_DRIVE)
    or a
    ret

; bdfs_has_device: check whether a device is present on the current drive's slot
; Side effect: selects the slot (JEDEC ID cache populated for flash_get_device_id)
; in:  — (uses BDFS_DRIVE)
; out: Z=device present
;      NZ=no device, A=BDFS_ERR_NO_DRIVE or BDFS_ERR_NO_DEVICE
; destroys: AF
bdfs_has_device:
    call bdfs_get_drive
    jr nz, _bhd_got_drive
    ld a, BDFS_ERR_NO_DRIVE
    or a
    ret
_bhd_got_drive:
    sub 'A'-1
    call flash_select_slot
    call flash_has_device
    ret z                            ; Z = device present
    ld a, BDFS_ERR_NO_DEVICE
    or a
    ret

; ---- bdfs_format -----------------------------------------------------------

; bdfs_format: erase sector 0 of the current drive and write a BDFS directory header
; in:  HL = volume name string (null-terminated, max BDFS_VOL_NAME_LEN-1 chars), or 0 for default
; out: Z=ok (format succeeded)
;      NZ=error, A=BDFS_ERR_* code
; destroys: AF
bdfs_format:
    push bc
    push de
    push hl
    call bdfs_get_drive
    jr nz, _bdfs_fmt_got_drive
    pop hl
    pop de
    pop bc
    ld a, BDFS_ERR_NO_DRIVE
    or a
    ret

_bdfs_fmt_got_drive:
    ld (BDFS_TMP), hl               ; stash name ptr across erase
    sub 'A'-1                       ; slot 1-6
    call flash_select_slot
    call flash_has_device
    jr z, _bdfs_fmt_has_device
    pop hl
    pop de
    pop bc
    ld a, BDFS_ERR_NO_DEVICE
    or a
    ret

_bdfs_fmt_has_device:
    ld h, 0x00                      ; addr[23:16]
    ld l, 0x00                      ; addr[15:8]
    call flash_sector_erase         ; Z=ok NZ=fail
    jr z, _bdfs_fmt_erase_ok
    pop hl
    pop de
    pop bc
    ld a, BDFS_ERR_ERASE_FAIL
    or a
    ret

_bdfs_fmt_erase_ok:
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
    ldir                            ; copy "BDFS-", DE now points past it
    ld a, (BDFS_DRIVE)
    ld (de), a
    inc de
    ld b, BDFS_VOL_NAME_LEN - _BDFS_DEFAULT_PREFIX_LEN - 1   ; remaining space after drive letter
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
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_page_program         ; Z=ok NZ=fail
    jr z, _bdfs_fmt_write_ok
    pop hl
    pop de
    pop bc
    ld a, BDFS_ERR_WRITE_FAIL
    or a
    ret

_bdfs_fmt_write_ok:
    ; read back to buffer
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ; verify magic
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _bdfs_fmt_magic_fail
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, _bdfs_fmt_magic_fail
    ; success
    pop hl
    pop de
    pop bc
    xor a                           ; Z set, A=0
    ret

_bdfs_fmt_magic_fail:
    pop hl
    pop de
    pop bc
    ld a, BDFS_ERR_VERIFY_FAIL
    or a
    ret

; ---- bdfs_dir_open ---------------------------------------------------------

; bdfs_dir_open: prepare to iterate the current drive's directory
; in:  —
; out: Z=ok, HL = pointer to null-terminated volume name (in BDFS_HDR_BUF)
;      NZ=error, A=BDFS_ERR_* (NO_DRIVE / NO_DEVICE / NOT_FORMATTED)
; destroys: AF, HL
bdfs_dir_open:
    push bc
    push de
    call bdfs_get_drive
    jr nz, _bdo_got_drive
    pop de
    pop bc
    ld a, BDFS_ERR_NO_DRIVE
    or a
    ret

_bdo_got_drive:
    sub 'A'-1
    call flash_select_slot
    call flash_has_device
    jr z, _bdo_has_device
    pop de
    pop bc
    ld a, BDFS_ERR_NO_DEVICE
    or a
    ret

_bdo_has_device:
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _bdo_not_formatted
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, _bdo_not_formatted
    ; initialise iterator state
    ld hl, BDFS_HDR_SIZE
    ld (BDFS_TMP), hl
    xor a
    ld (BDFS_ACTIVE_COUNT), a
    ; return vol name pointer
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    pop de
    pop bc
    xor a                           ; Z set
    ret

_bdo_not_formatted:
    pop de
    pop bc
    ld a, BDFS_ERR_NOT_FORMATTED
    or a
    ret

; ---- bdfs_dir_next ---------------------------------------------------------

; bdfs_dir_next: read the next directory entry into BDFS_ENT_BUF
; in:  — (iterator state in BDFS_TMP / BDFS_ACTIVE_COUNT, set by bdfs_dir_open)
; out: Z=ok, HL = pointer to entry (BDFS_ENT_BUF); check flags byte for deleted status
;      NZ=done (no more entries), A = active entry count
; destroys: AF, HL
bdfs_dir_next:
    push bc
    push de
    xor a                           ; addr[23:16] = 0x00
    ld hl, (BDFS_TMP)               ; addr[15:0] = current iterator position
    ld de, BDFS_ENT_BUF
    ld bc, BDFS_ENT_SIZE
    call flash_read
    ; empty entry signals end of directory
    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET)
    cp BDFS_ENT_EMPTY
    jr z, _bdn_empty
    ; advance iterator to next entry
    ld hl, (BDFS_TMP)
    ld bc, BDFS_ENT_SIZE
    add hl, bc
    ld (BDFS_TMP), hl
    ; increment active count only for non-deleted entries
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _bdn_return              ; deleted: skip count increment
    ld a, (BDFS_ACTIVE_COUNT)
    inc a
    ld (BDFS_ACTIVE_COUNT), a
_bdn_return:
    ld hl, BDFS_ENT_BUF
    pop de
    pop bc
    xor a                           ; Z set
    ret

_bdn_empty:
    ld a, (BDFS_ACTIVE_COUNT)
    ld b, a                         ; save count
    inc a                           ; ensure non-zero for count 0-254 (NZ signal for "done")
    ld a, b                         ; restore count (LD does not affect flags)
    pop de
    pop bc
    ret                             ; NZ, A = active entry count

; ---- _bdfs_parse_filename --------------------------------------------------

; _bdfs_parse_filename: parse 8.3 filename string into BDFS_ENT_BUF name/ext fields
; in:  HL = null-terminated filename (e.g. "HELLO.TXT"); case-sensitive, stored verbatim
; out: BDFS_ENT_BUF bytes 0-10 filled (name space-padded to 8, ext space-padded to 3)
; destroys: AF, BC, DE, HL
_bdfs_parse_filename:
    ld de, BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET
    ld b, BDFS_NAME_LEN             ; 8 chars remaining in name field
_pfn_name_loop:
    ld a, (hl)
    or a
    jr z, _pfn_name_end             ; null: end of string before name full
    cp '.'
    jr z, _pfn_dot                  ; dot: switch to ext
    ld (de), a
    inc hl
    inc de
    djnz _pfn_name_loop
    ; name field full: skip chars until dot or null
_pfn_skip_to_dot:
    ld a, (hl)
    or a
    jr z, _pfn_no_dot               ; null reached with no dot
    inc hl
    cp '.'
    jr nz, _pfn_skip_to_dot
    jr _pfn_ext                     ; dot found, HL points to first ext char

_pfn_name_end:
    ; null found mid-name: space-fill remainder of name field
_pfn_name_fill:
    ld a, ' '
    ld (de), a
    inc de
    djnz _pfn_name_fill
_pfn_no_dot:
    ; no dot in filename: fill ext field with spaces
    ld de, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN
    ld a, ' '
_pfn_no_dot_fill:
    ld (de), a
    inc de
    djnz _pfn_no_dot_fill
    ret

_pfn_dot:
    inc hl                          ; skip past the dot
    ; space-fill remainder of name field (B = chars still to fill)
_pfn_name_fill_after_dot:
    ld a, ' '
    ld (de), a
    inc de
    djnz _pfn_name_fill_after_dot
_pfn_ext:
    ld de, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN              ; 3 chars in ext field
_pfn_ext_loop:
    ld a, (hl)
    or a
    jr z, _pfn_ext_fill             ; null: space-fill remaining ext
    ld (de), a
    inc hl
    inc de
    djnz _pfn_ext_loop
    ret                             ; ext field full
_pfn_ext_fill:
    ld a, ' '
    ld (de), a
    inc de
    djnz _pfn_ext_fill
    ret

; ---- strings ---------------------------------------------------------------

_BDFS_DEFAULT_PREFIX:       db "BDFS-"
_BDFS_DEFAULT_PREFIX_LEN    equ $ - _BDFS_DEFAULT_PREFIX
