; spi_beanboardspi_reva.asm - SPI byte transfer for BeanBoardSPI Rev A
;
; Rev A does not have a status register; serialisation complete is
; determined by a fixed NOP delay after each byte write.
;
; TODO: NOP count (8) is calibrated for 10 MHz Z80 at CLK/2 (5 MHz SPI,
; ~1.6 us/byte). Adjust if running at a different CPU clock speed.
; A general delay calibration mechanism is needed across the codebase —
; see ra8875-z80-repo/README.md delays TODO.
;
; Interface (PUBLIC):
;   spi_read - receive one byte (transmits 0x00); returns byte in A
;   spi_byte - transmit A, receive one byte (full-duplex); returns byte in A

    PUBLIC spi_byte
    PUBLIC spi_read

    EXTERN SPI_CTRL             ; system.asm - SPI control/status port
    EXTERN SPI_DATA             ; system.asm - SPI data port

; spi_read: receive one byte, transmitting 0x00
; out: A = byte received
; destroys: AF
spi_read:
    xor a                       ; A = 0x00 (dummy transmit byte)
                                ; fall through to spi_byte

; spi_byte: full-duplex SPI byte transfer
; in:  A = byte to transmit
; out: A = byte received
; destroys: AF
spi_byte:
    out (SPI_DATA), a
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    in a, (SPI_DATA)
    ret
