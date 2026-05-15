; bdfs.asm - BeanDeck File System (pure data/operation layer)
;
; bdfs_init: initialise RAM state; call once at startup.
; Drive selection: bdfs_set_drive / bdfs_get_drive, letters 'A'-'F' mapped to slots 1-6.
; bdfs_select_drive: make a drive active ready for read/write
; bdfs_format: erase and write header; returns Z=ok, NZ=error (A=BDFS_ERR_*).
; bdfs_dir_open / bdfs_dir_next: iterator for directory entries (no output).
;
; Deletion and free-space fragmentation:
;   Deleting a file marks its directory entry as deleted but does not erase its sectors.
;   New files are written after the last *active* file's end sector, so deleted sectors
;   at the tail of used space are silently reclaimed; deleted sectors surrounded by active
;   files are stranded until a full reclaim (e.g. copy all active files to a second drive,
;   format this drive, copy back - or some other reclaim / defrag process).
;
; Flash medium assumptions (coupled to underlying device geometry):
;   Sector size : 4096 bytes — erase unit; directory sector holds exactly 255 entries
;                 (16-byte header + 255 × 16-byte entries = 4096)
;   Page size   : 256 bytes  — write unit; file data written in 256-byte pages
;   Address width: 24 bits   — passed as A:HL (A = addr[23:16], HL = addr[15:0])
;   Directory   : sector 0; file data starts at sector 1 (BDFS_DATA_START_SECTOR)

    INCLUDE "asm/bdfs.inc"

; Magic bytes - used on the directory sector to indicate a formatted drive
BDFS_MAGIC_0            EQU 0xBD
BDFS_MAGIC_1            EQU 0x01

; volume layout
BDFS_DIR_SECTOR         EQU 0x0000
BDFS_DATA_START_SECTOR  EQU 0x0001

; Entry state
BDFS_FLAG_ACTIVE      EQU 0x00
BDFS_ENT_EMPTY        EQU 0xFF    ; name[0] = FF means no more entries; 0xFF is the erased state, names can't include 0xFF

; Format field sizes
; BDFS_HDR_SIZE and BDFS_ENT_SIZE are both multiples of W25Q_PAGE_SIZE (256) and
; exact divisors of W25Q_SECTOR_SIZE (4096), so reads and writes never cross page
; or sector boundaries. As a result the directory sector holds exactly 4096/16 - 1 = 255 entries.
BDFS_VOL_NAME_LEN     EQU 12
BDFS_HDR_SIZE         EQU 16   ; 2 (magic) + 12 (vol name) + 2 (reserved)
BDFS_ENT_SIZE         EQU 16   ; 8 (name) + 3 (ext) + 2 (sector) + 2 (length) + 1 (flags)

; Directory header offsets
BDFS_HDR_MAGIC_OFFSET        EQU 0       ; 2 bytes
BDFS_HDR_RESERVED_OFFSET     EQU 14      ; 2 bytes

; Directory entry offsets (additional to those shared via bdfs.inc)
BDFS_ENT_SECTOR_OFFSET       EQU 11      ; 2 bytes, little-endian
BDFS_ENT_LENGTH_OFFSET       EQU 13      ; 2 bytes, little-endian (max 65535)

; Error codes (additional to those shared via bdfs.inc)
BDFS_ERR_NO_DEVICE      EQU 2
BDFS_ERR_DIR_FULL       EQU 7   ; all 255 entry slots occupied
BDFS_ERR_DISK_FULL      EQU 8   ; not enough free sectors for the file

    PUBLIC bdfs_init
    PUBLIC bdfs_select_drive
    PUBLIC bdfs_format
    PUBLIC bdfs_dir_open
    PUBLIC bdfs_dir_next
    PUBLIC bdfs_file_write
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
    EXTERN flash_get_sector_count
    EXTERN flash_bytes_to_sectors
    EXTERN flash_sector_to_addr
    EXTERN flash_read
    EXTERN BDFS_RAMSTART
    EXTERN W25Q_SECTOR_SIZE     ; hardware geometry — erase unit
    EXTERN W25Q_PAGE_SIZE       ; hardware geometry — write unit

; Aliases coupling BDFS to W25Q geometry (hardware dependency made explicit)
_SECTOR_SIZE    EQU W25Q_SECTOR_SIZE
_PAGE_SIZE      EQU W25Q_PAGE_SIZE
_MAX_ENTRIES    EQU (_SECTOR_SIZE / BDFS_ENT_SIZE) - 1  ; -1 : header occupies one slot

; ---- RAM layout (private to this module) ------------------------------------

BDFS_HDR_BUF            EQU BDFS_RAMSTART                        ; directory header r/w buffer
BDFS_ENT_BUF            EQU BDFS_HDR_BUF + BDFS_HDR_SIZE         ; entry scan buffer
_DIR_SCAN_OFST          EQU BDFS_ENT_BUF + BDFS_ENT_SIZE             ; directory iterator scan offset (2 bytes)
_DIR_SCAN_OFST_LEN      EQU 2
_ACTIVE_COUNT           EQU _DIR_SCAN_OFST + _DIR_SCAN_OFST_LEN      ; active entry count (1 byte)
_ACTIVE_COUNT_LEN       EQU 1
BDFS_DRIVE              EQU _ACTIVE_COUNT + _ACTIVE_COUNT_LEN    ; active drive letter ('A'-'F', 0=none)
_DRIVE_LEN              EQU 1
_FREE_ENTRY_OFFSET      EQU BDFS_DRIVE + _DRIVE_LEN                                  ; first free dir entry byte offset from scan (2 bytes)
_FREE_ENTRY_OFFSET_LEN  EQU 2
_NEXT_FREE_SECTOR       EQU _FREE_ENTRY_OFFSET + _FREE_ENTRY_OFFSET_LEN             ; next free sector number from scan (2 bytes)
_NEXT_FREE_SECTOR_LEN   EQU 2
_PAGE_ADDR_BANK         EQU _NEXT_FREE_SECTOR + _NEXT_FREE_SECTOR_LEN               ; addr[23:16] during page writes (1 byte)
_PAGE_ADDR_BANK_LEN     EQU 1
BDFS_RAMSIZE            EQU BDFS_HDR_SIZE + BDFS_ENT_SIZE + _DIR_SCAN_OFST_LEN + _ACTIVE_COUNT_LEN + _DRIVE_LEN + _FREE_ENTRY_OFFSET_LEN + _NEXT_FREE_SECTOR_LEN + _PAGE_ADDR_BANK_LEN

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
; out: Z=ok, A = drive letter ('A'-'F')
;      NZ=no drive, A=BDFS_ERR_NO_DRIVE
; destroys: AF
bdfs_get_drive:
    ld a, (BDFS_DRIVE)
    or a
    jr z, _get_drive_no_drive
    cp a                            ; Z set, A = drive letter unchanged
    ret
_get_drive_no_drive:
    ld a, BDFS_ERR_NO_DRIVE
    or a
    ret

; bdfs_select_drive: select the slot for a drive letter and verify a device is present
; in:  A = drive letter ('A'-'F')
; out: Z=ok, NZ=error A=BDFS_ERR_NO_DEVICE
; destroys: AF, BC
bdfs_select_drive:
    sub 'A'-1                       ; A = slot number (1-6)
    call flash_select_slot
    call flash_has_device
    ret z
    ld a, BDFS_ERR_NO_DEVICE
    or a
    ret

; ---- bdfs_format -----------------------------------------------------------

; bdfs_format: erase sector 0 of the current drive and write a BDFS directory header
; assumes bdfs_select_drive has been called for the target drive
; in:  HL = volume name string (null-terminated, max BDFS_VOL_NAME_LEN-1 chars), or 0 for default
; out: Z=ok (format succeeded)
;      NZ=error, A=BDFS_ERR_* code
; destroys: AF
bdfs_format:
    push bc
    push de
    push hl                         ; name ptr
    ld hl, BDFS_DIR_SECTOR          ; sector 0 = directory sector
    call flash_sector_erase         ; Z=ok NZ=fail
    jr z, _format_erase_ok
    ld a, BDFS_ERR_ERASE_FAIL
    jp _format_exit
_format_erase_ok:
    ; build 16-byte header in BDFS_HDR_BUF: magic + vol_name + reserved
    ld hl, BDFS_HDR_BUF
    ld (hl), BDFS_MAGIC_0
    inc hl
    ld (hl), BDFS_MAGIC_1
    inc hl
    ex de, hl                       ; DE = vol_name field ptr
    pop hl                          ; HL = name ptr (saved on stack at entry)
    push hl                         ; restore stack for exit
    ld a, h
    or l
    jr z, _format_default_name
    ; custom name: copy up to BDFS_VOL_NAME_LEN chars, ensure null-terminated
    ld b, BDFS_VOL_NAME_LEN
_format_copy_name:
    ld a, (hl)
    or a
    jr z, _format_name_null_fill       ; end of source: null-fill remaining
    ld (de), a
    inc hl
    inc de
    djnz _format_copy_name
    ; wrote full BDFS_VOL_NAME_LEN chars: overwrite last with null terminator
    dec de
    xor a
    ld (de), a
    inc de
    jr _format_reserved
_format_name_null_fill:
    xor a
_format_name_null_fill_loop:
    ld (de), a
    inc de
    djnz _format_name_null_fill_loop
    jr _format_reserved
_format_default_name:
    ld hl, _BDFS_DEFAULT_PREFIX
    ld bc, _BDFS_DEFAULT_PREFIX_LEN
    ldir                            ; copy "BDFS-", DE now points past it
    ld a, (BDFS_DRIVE)
    ld (de), a
    inc de
    ld b, BDFS_VOL_NAME_LEN - _BDFS_DEFAULT_PREFIX_LEN - 1   ; remaining space after drive letter
_format_default_name_null_fill:
    xor a
    ld (de), a
    inc de
    djnz _format_default_name_null_fill
_format_reserved:
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
    jr z, _format_write_ok
    ld a, BDFS_ERR_WRITE_FAIL
    jp _format_exit
_format_write_ok:
    ; read back to buffer
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ; verify magic
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _format_verify_magic_fail
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, _format_verify_magic_fail
    ; success
    xor a                           ; Z set, A=0
    jr _format_exit
_format_verify_magic_fail:
    ld a, BDFS_ERR_VERIFY_FAIL
_format_exit:
    pop hl
    pop de
    pop bc
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
    jr nz, _bdo_no_drive
    sub 'A'-1
    call flash_select_slot
    call flash_has_device
    jr z, _bdo_has_device
    pop de
    pop bc
    ld a, BDFS_ERR_NO_DEVICE
    or a
    ret
_bdo_no_drive:
    pop de
    pop bc
    or a                            ; A = BDFS_ERR_NO_DRIVE, ensure NZ
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
    ld (_DIR_SCAN_OFST), hl
    xor a
    ld (_ACTIVE_COUNT), a
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
; in:  — (iterator state in _DIR_SCAN_OFST / _ACTIVE_COUNT, set by bdfs_dir_open)
; out: Z=ok, HL = pointer to entry (BDFS_ENT_BUF); check flags byte for deleted status
;      NZ=done (no more entries), A = active entry count
; destroys: AF, HL
bdfs_dir_next:
    push bc
    push de
    xor a                           ; addr[23:16] = 0x00
    ld hl, (_DIR_SCAN_OFST)         ; addr[15:0] = current iterator position
    ld de, BDFS_ENT_BUF
    ld bc, BDFS_ENT_SIZE
    call flash_read
    ; empty entry signals end of directory
    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET)
    cp BDFS_ENT_EMPTY
    jr z, _bdn_empty
    ; advance iterator to next entry
    ld hl, (_DIR_SCAN_OFST)
    ld bc, BDFS_ENT_SIZE
    add hl, bc
    ld (_DIR_SCAN_OFST), hl
    ; increment active count only for non-deleted entries
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _bdn_return              ; deleted: skip count increment
    ld a, (_ACTIVE_COUNT)
    inc a
    ld (_ACTIVE_COUNT), a
_bdn_return:
    ld hl, BDFS_ENT_BUF
    pop de
    pop bc
    xor a                           ; Z set
    ret

_bdn_empty:
    ld a, (_ACTIVE_COUNT)
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

; ---- bdfs_file_write -------------------------------------------------------

; bdfs_file_write: write a file to the current drive (steps 1-5: validate, scan,
;                  disk-full check, erase, write pages; directory entry pending)
; in:  HL = filename (null-terminated "NAME.EXT", uppercase)
;      DE = source address in RAM
;      BC = length in bytes
; out: Z=ok, NZ=error (A=BDFS_ERR_*)
; destroys: AF, BC, DE, HL, IX
bdfs_file_write:
    push bc                         ; save length
    push de                         ; save source
    push hl                         ; save filename

; --- Step 1: validate drive, device, format ---------------------------------

    call bdfs_get_drive
    jr nz, _bfw_no_drive
    sub 'A'-1
    call flash_select_slot
    call flash_has_device
    jr z, _bfw_has_device
    pop hl
    pop de
    pop bc
    ld a, BDFS_ERR_NO_DEVICE
    or a
    ret
_bfw_no_drive:
    pop hl
    pop de
    pop bc
    or a                            ; A = BDFS_ERR_NO_DRIVE, ensure NZ
    ret

_bfw_has_device:
    xor a
    ld hl, 0x0000
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, _bfw_not_formatted
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr z, _bfw_step2
_bfw_not_formatted:
    pop hl
    pop de
    pop bc
    ld a, BDFS_ERR_NOT_FORMATTED
    or a
    ret

; --- Step 2: directory scan -------------------------------------------------
;
; Scans entries to find:
;   _FREE_ENTRY_OFFSET = flash byte address of first empty directory slot
;   _NEXT_FREE_SECTOR  = sector number after the last active file
;
; IX = scan_offset (flash byte address of current entry)
; B  = entries scanned (up to 255)

_bfw_step2:
    ld hl, 0x0000
    ld (_FREE_ENTRY_OFFSET), hl     ; = 0 (not yet found)
    ld hl, BDFS_DATA_START_SECTOR
    ld (_NEXT_FREE_SECTOR), hl      ; = first data sector
    ld ix, BDFS_HDR_SIZE            ; scan_offset = first entry
    ld b, 0                         ; entry count

_bfw_scan_loop:
    push ix                         ; IX => HL = scan_offset
    pop hl                          ; lower 16 bits of address
    xor a                           ; zero A = top 8 bits address
    push bc                         ; save B = entry count across flash_read
    ld de, BDFS_ENT_BUF             ; destination
    ld bc, BDFS_ENT_SIZE            ; byte count
    call flash_read                 ; load into entry buffer
    pop bc                          ; restore B = entry count

    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET) ; first char of file name in entry buffer
    cp BDFS_ENT_EMPTY
    jr z, _bfw_scan_found_empty_entry

    ; check flags: skip deleted entries (don't update next_free_sector)
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr nz, _bfw_scan_next

    ; active entry: end_sector = start_sector + num_sectors
    ld hl, (BDFS_ENT_BUF + BDFS_ENT_LENGTH_OFFSET) ; file length bytes
    call flash_bytes_to_sectors     ; A = num sectors
    ld hl, (BDFS_ENT_BUF + BDFS_ENT_SECTOR_OFFSET)
    ld d, 0
    ld e, a
    add hl, de                      ; HL = end_sector
    ld (_NEXT_FREE_SECTOR), hl      ; always ascending: last active entry wins

_bfw_scan_next:
    ld de, BDFS_ENT_SIZE
    add ix, de                      ; advance scan_offset
    inc b                           ; entry count
    ld a, b
    cp _MAX_ENTRIES                 ; directory sector full
    jp z, _bfw_dir_full
    jr _bfw_scan_loop

_bfw_scan_found_empty_entry:
    push ix
    pop hl
    ld (_FREE_ENTRY_OFFSET), hl

; --- Step 3: disk-full check ------------------------------------------------

_bfw_step3:
    pop hl                          ; discard filename
    pop de                          ; DE = source
    pop bc                          ; BC = length
    push de                         ; re-save source
    push bc                         ; re-save length

    ld h, b
    ld l, c                         ; HL = length
    call flash_bytes_to_sectors     ; A = sectors_needed
    push af                         ; save sectors_needed

    ld hl, (_NEXT_FREE_SECTOR)
    ld d, 0
    ld e, a
    add hl, de                      ; HL = next_free_sector + sectors_needed
    push hl
    call flash_get_sector_count     ; HL = total sector count
    ex de, hl                       ; DE = total
    pop hl                          ; HL = next_free + needed

    ; disk full if HL > DE (strictly greater than)
    ld a, h
    cp d
    jr c, _bfw_step4             ; HL < DE: ok
    jr nz, _bfw_disk_full           ; H > D: disk full
    ld a, l
    cp e
    jr c, _bfw_step4             ; HL < DE (low byte, high equal): ok
    jr z, _bfw_step4             ; HL = DE: exactly fills device, ok
_bfw_disk_full:
    pop af                          ; discard sectors_needed
    pop bc                          ; discard length
    pop de                          ; discard source
    ld a, BDFS_ERR_DISK_FULL
    or a
    ret

; --- Step 4: erase data sectors ---------------------------------------------
_bfw_step4:
    pop af                          ; A = sectors_needed
    ld b, a                         ; B = sectors_needed (loop count)
    ld ix, (_NEXT_FREE_SECTOR)
_bfw_erase_loop:
    push ix                         ; IX => HL
    pop hl                          ; = current sector number
    call flash_sector_erase         ; Z=ok, NZ=timeout
    jr nz, _bfw_erase_fail
    inc ix                          ; next sector
    djnz _bfw_erase_loop

; --- Step 5: write file data in 256-byte pages ------------------------------

_bfw_step5:
    pop bc                          ; BC = length (pushed last in step 3, so on top)
    pop de                          ; DE = source

    ld hl, (_NEXT_FREE_SECTOR)
    call flash_sector_to_addr       ; A = addr[23:16], HL = addr[15:0]
    ld (_PAGE_ADDR_BANK), a         ; save addr[23:16] for use across page_program calls

_bfw_page_loop:
    ld a, b
    or c
    jr z, _bfw_write_ok             ; BC = 0: done

    ld a, b
    or a
    jr z, _bfw_partial_page         ; B = 0: fewer than 256 bytes remain

    ; full 256-byte page
    ld a, (_PAGE_ADDR_BANK)         ; A = addr[23:16]
    push bc                         ; save remaining count
    ld bc, _PAGE_SIZE
    call flash_page_program         ; A:HL=addr, DE=src, BC=_PAGE_SIZE → Z=ok NZ=timeout; preserves HL, BC; DE advances
    pop bc                          ; restore remaining count
    jr nz, _bfw_write_fail
    inc h                           ; addr[15:8]++: advance to next page
    jr nz, _bfw_page_inc_ok
    ld a, (_PAGE_ADDR_BANK)         ; H wrapped: propagate carry into addr[23:16]
    inc a
    ld (_PAGE_ADDR_BANK), a
_bfw_page_inc_ok:
dec b                               ; remaining -= 256
    jr _bfw_page_loop

_bfw_partial_page:
    ; B = 0, C = remaining bytes (< 256); write and finish
    ld a, (_PAGE_ADDR_BANK)         ; A = addr[23:16]
    call flash_page_program         ; A:HL=addr, DE=src, BC=C bytes
    jr nz, _bfw_write_fail

_bfw_write_ok:
    xor a                           ; Z set, A = 0
    ret

_bfw_write_fail:
    ld a, BDFS_ERR_WRITE_FAIL
    or a
    ret

_bfw_dir_full:
    pop hl                          ; discard filename
    pop de                          ; discard source
    pop bc                          ; discard length
    ld a, BDFS_ERR_DIR_FULL
    or a
    ret

_bfw_erase_fail:
    pop bc                          ; saved length
    pop de                          ; saved source
    ld a, BDFS_ERR_ERASE_FAIL
    or a
    ret

; ---- strings ---------------------------------------------------------------

_BDFS_DEFAULT_PREFIX:       db "BDFS-"
_BDFS_DEFAULT_PREFIX_LEN    equ $ - _BDFS_DEFAULT_PREFIX
