; bdfs.inc - BeanDeck File System constants
;
; Included by bdfs.asm (pure data layer) and bdfs_mon.asm (monitor presentation layer).

; Entry flags (bit 0 of flags byte: 0=active, 1=deleted)
BDFS_FLAG_DELETED_BIT EQU 0

; Format field sizes
BDFS_NAME_LEN         EQU 8
BDFS_EXT_LEN          EQU 3

; Directory header offsets
BDFS_HDR_VOL_NAME_OFFSET     EQU 2       ; 12 bytes

; Directory entry offsets (8.3 filename: name and ext fields, space-padded, no dot stored)
BDFS_ENT_NAME_OFFSET         EQU 0       ; 8 bytes, space-padded uppercase basename
BDFS_ENT_EXT_OFFSET          EQU 8       ; 3 bytes, space-padded uppercase extension
BDFS_ENT_FLAGS_OFFSET        EQU 15      ; 1 byte

; Drive range
BDFS_FIRST_DRIVE        EQU 'A'
BDFS_LAST_DRIVE         EQU 'F'

; Error codes
BDFS_ERR_NO_DRIVE       EQU 1
BDFS_ERR_NO_DEVICE      EQU 2
BDFS_ERR_NOT_FORMATTED  EQU 3
BDFS_ERR_ERASE_FAIL     EQU 4
BDFS_ERR_WRITE_FAIL     EQU 5
BDFS_ERR_VERIFY_FAIL    EQU 6
BDFS_ERR_DIR_FULL       EQU 7
BDFS_ERR_DISK_FULL      EQU 8
BDFS_ERR_END_OF_DIR     EQU 9
BDFS_ERR_BAD_DRIVE      EQU 10
BDFS_ERR_FILE_NOT_FOUND EQU 11
