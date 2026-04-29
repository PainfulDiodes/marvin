; bdfs.inc - BeanDeck File System on-flash directory format constants

BDFS_MAGIC_0          EQU 0xBD
BDFS_MAGIC_1          EQU 0x01
BDFS_DIR_SECTOR       EQU 0x0000
BDFS_DATA_START       EQU 0x0001

; Header offsets
BDFS_HDR_MAGIC        EQU 0       ; 2 bytes
BDFS_HDR_VOL_NAME     EQU 2       ; 12 bytes
BDFS_HDR_RESERVED     EQU 14      ; 2 bytes
BDFS_HDR_SIZE         EQU 16

; Entry offsets (8.3 filename: separate name and ext fields, space-padded, no dot stored)
BDFS_ENT_NAME         EQU 0       ; 8 bytes, space-padded uppercase basename
BDFS_ENT_EXT          EQU 8       ; 3 bytes, space-padded uppercase extension
BDFS_ENT_SECTOR       EQU 11      ; 2 bytes, little-endian
BDFS_ENT_LENGTH       EQU 13      ; 3 bytes, little-endian
BDFS_ENT_FLAGS        EQU 16      ; 1 byte
BDFS_ENT_SIZE         EQU 17

BDFS_FLAG_ACTIVE      EQU 0x00
BDFS_FLAG_DELETED_BIT EQU 0
BDFS_ENT_EMPTY        EQU 0xFF    ; name[0] value meaning no more entries

BDFS_NAME_LEN         EQU 8
BDFS_EXT_LEN          EQU 3
BDFS_VOL_NAME_LEN     EQU 12
