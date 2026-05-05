; w25q.asm - W25Q series NOR flash driver for BeanBoardSPI hardware SPI
;
; All functions preserve caller registers unless documented otherwise.
; flash_read, flash_sector_erase, and flash_page_program consume their
; input registers (they do not restore HL, DE, BC on return).
;
; flash_read disturbs AF' (uses ex af,af' to save addr[23:16] across CS assert).

    INCLUDE "asm/drivers/w25q.inc"

    EXTERN SPI_CTRL, SPI_DATA, SPI_CS_IDLE  ; system.asm - BeanBoardSPI port addresses
    EXTERN W25Q_RAMSTART                    ; system.asm - base address of W25Q RAM block

    PUBLIC flash_read
    PUBLIC flash_read_jedec_id
    PUBLIC flash_sector_erase
    PUBLIC flash_page_program
    PUBLIC flash_select_slot
    PUBLIC W25Q_RAMSIZE

; ---- RAM layout (private to this module) ------------------------------------

W25Q_CS             equ W25Q_RAMSTART + 0   ; 1 byte: active CS byte for flash_cs_assert
W25Q_ID_MFR         equ W25Q_RAMSTART + 1   ; 1 byte: JEDEC manufacturer ID (cached by flash_select_slot)
W25Q_ID_TYPE        equ W25Q_RAMSTART + 2   ; 1 byte: JEDEC memory type
W25Q_ID_CAP         equ W25Q_RAMSTART + 3   ; 1 byte: JEDEC capacity code (see W25Q_CAP_* in w25q.inc)
W25Q_RAMSIZE        equ 4


; flash_spi_byte: full-duplex SPI byte transfer via BeanBoardSPI interface
; in:  A = byte to transmit
; out: A = byte received
; destroys: AF
; TODO: move to central BeanBoardSPI source
flash_spi_byte:
    out (SPI_DATA), a
    nop                     ; wait for serialisation (CLK/2 = 5 MHz)
    nop
    nop
    in a, (SPI_DATA)
    ret

; flash_read_jedec_id: read 3-byte JEDEC ID
; out: A = manufacturer ID, B = memory type, C = capacity
; destroys: AF, BC
flash_read_jedec_id:
    push de
    push hl
    ld a, (W25Q_CS)             ; RAM var selected status for current slot
    out (SPI_CTRL), a
    ld a, W25Q_CMD_JEDEC_ID
    call flash_spi_byte         ; received byte discarded
    ld a, 0x00
    call flash_spi_byte
    ld d, a                     ; manufacturer in D
    ld a, 0x00
    call flash_spi_byte
    ld e, a                     ; memory type in E
    ld a, 0x00
    call flash_spi_byte
    ld l, a                     ; capacity in L
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    ld c, l                     ; C = capacity
    ld b, e                     ; B = memory type
    ld a, d                     ; A = manufacturer ID
    pop hl
    pop de
    ret

; flash_write_enable: send Write Enable command (own CS transaction)
; destroys: nothing
flash_write_enable:
    push af
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_WREN
    call flash_spi_byte
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    pop af
    ret

; flash_poll_busy: poll status register until BUSY (bit 0) clears or timeout
; out: Z = done (not busy), NZ = timeout
; destroys: AF, BC, DE
flash_poll_busy:
    ld de, W25Q_POLL_TIMEOUT
_fpb_loop:
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_RDSR
    call flash_spi_byte
    ld a, 0x00
    call flash_spi_byte         ; A = status register byte
    ld b, a                     ; save in B before deassert clobbers A
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    bit W25Q_BUSY_BIT, b        ; Z=1 if BUSY bit is 0 (not busy)
    jr z, _fpb_done
    dec de
    ld a, d
    or e
    jr nz, _fpb_loop
    or 1                        ; timeout: set NZ (A was 0, or 1 = 1)
    ret
_fpb_done:
    ret                         ; Z set: operation complete

; flash_read: read BC bytes from flash address A:HL into RAM at DE
; in:  A  = addr[23:16]
;      HL = addr[15:0]  (H = addr[15:8], L = addr[7:0])
;      DE = destination (RAM pointer)
;      BC = byte count
; out: DE = one past last byte written, BC = 0
; destroys: AF, AF', BC, DE, HL
flash_read:
    ex af, af'                  ; A' = addr[23:16]; save before CS assert clobbers A
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_READ
    call flash_spi_byte
    ex af, af'                  ; A = addr[23:16]
    call flash_spi_byte         ; send addr[23:16]
    ld a, h
    call flash_spi_byte         ; send addr[15:8]
    ld a, l
    call flash_spi_byte         ; send addr[7:0]
_fr_loop:
    ld a, 0x00
    call flash_spi_byte         ; clock in received byte
    ld (de), a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, _fr_loop
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    ret

; flash_sector_erase: send Write Enable, erase 4KB sector at HL, poll until done
; in:  H = addr[23:16], L = addr[15:8]  (sector must be 4KB-aligned; addr[7:0] = 0)
; out: Z = ok, NZ = timeout
; destroys: AF, BC, DE, HL
flash_sector_erase:
    call flash_write_enable
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_SE
    call flash_spi_byte
    ld a, h
    call flash_spi_byte         ; addr[23:16]
    ld a, l
    call flash_spi_byte         ; addr[15:8]
    ld a, 0x00
    call flash_spi_byte         ; addr[7:0] = 0
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    jp flash_poll_busy          ; tail call: Z=ok NZ=timeout

; flash_page_program: send Write Enable, write BC bytes from DE to flash page at HL, poll
; in:  H = addr[23:16], L = addr[15:8]  (page must be 256-byte-aligned; addr[7:0] = 0)
;      DE = source (RAM pointer)
;      BC = byte count (must be ≤ 256)
; out: Z = ok, NZ = timeout
; destroys: AF, BC, DE, HL
flash_page_program:
    call flash_write_enable
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_PP
    call flash_spi_byte
    ld a, h
    call flash_spi_byte         ; addr[23:16]
    ld a, l
    call flash_spi_byte         ; addr[15:8]
    ld a, 0x00
    call flash_spi_byte         ; addr[7:0] = 0
_fpp_loop:
    ld a, (de)
    call flash_spi_byte
    inc de
    dec bc
    ld a, b
    or c
    jr nz, _fpp_loop
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    jp flash_poll_busy          ; tail call: Z=ok NZ=timeout

; flash_select_slot: select active cartridge slot - defined in W25Q_CS - and cache the device JEDEC ID
; in:  A = slot number (1-6)
; out: —  (JEDEC ID cached in W25Q_ID_MFR, W25Q_ID_TYPE, W25Q_ID_CAP)
; destroys: AF
flash_select_slot:
    push bc
    inc a                       ; A = slot + 1 (bit position of CS line)
    ld b, a                     ; B = shift count
    ld a, 1
_fss_loop:
    rlca
    djnz _fss_loop              ; A = 1 << (slot+1): the active-low CS bit for this slot
    cpl                         ; invert: 0xFF with CS bit cleared
    ld (W25Q_CS), a
    call flash_read_jedec_id    ; A=mfr, B=type, C=cap (uses W25Q_CS just set)
    ld (W25Q_ID_MFR), a
    ld a, b
    ld (W25Q_ID_TYPE), a
    ld a, c
    ld (W25Q_ID_CAP), a
    pop bc
    ret
