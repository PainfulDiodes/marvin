; bdfs.inc - BeanDeck File System constants
;
; Included by bdfs.asm (pure data layer) and bdfs_mon.asm (monitor presentation layer).

; Magic bytes
BDFS_MAGIC_0          EQU 0xBD
BDFS_MAGIC_1          EQU 0x01
BDFS_DIR_SECTOR       EQU 0x0000
BDFS_DATA_START       EQU 0x0001

; Entry flags (bit 0 of flags byte: 0=active, 1=deleted)
BDFS_FLAG_ACTIVE      EQU 0x00
BDFS_FLAG_DELETED_BIT EQU 0
BDFS_ENT_EMPTY        EQU 0xFF    ; name[0] = FF means no more entries

; Field sizes
BDFS_NAME_LEN         EQU 8
BDFS_EXT_LEN          EQU 3
BDFS_VOL_NAME_LEN     EQU 12
BDFS_HDR_SIZE         EQU 16
BDFS_ENT_SIZE         EQU 16

; Directory header offsets
BDFS_HDR_MAGIC_OFFSET        EQU 0       ; 2 bytes
BDFS_HDR_VOL_NAME_OFFSET     EQU 2       ; 12 bytes
BDFS_HDR_RESERVED_OFFSET     EQU 14      ; 2 bytes

; Directory entry offsets (8.3 filename: name and ext fields, space-padded, no dot stored)
BDFS_ENT_NAME_OFFSET         EQU 0       ; 8 bytes, space-padded uppercase basename
BDFS_ENT_EXT_OFFSET          EQU 8       ; 3 bytes, space-padded uppercase extension
BDFS_ENT_SECTOR_OFFSET       EQU 11      ; 2 bytes, little-endian
BDFS_ENT_LENGTH_OFFSET       EQU 13      ; 2 bytes, little-endian (max 65535)
BDFS_ENT_FLAGS_OFFSET        EQU 15      ; 1 byte

; Error codes
BDFS_ERR_NO_DRIVE       EQU 1
BDFS_ERR_NO_DEVICE      EQU 2
BDFS_ERR_NOT_FORMATTED  EQU 3
BDFS_ERR_ERASE_FAIL     EQU 4
BDFS_ERR_WRITE_FAIL     EQU 5
BDFS_ERR_VERIFY_FAIL    EQU 6
BDFS_ERR_DIR_FULL       EQU 7   ; all 255 entry slots occupied
BDFS_ERR_DISK_FULL      EQU 8   ; not enough free sectors for the file
