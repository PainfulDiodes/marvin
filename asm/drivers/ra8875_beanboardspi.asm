;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ra8875_beanboardspi.asm - RA8875 transport shim for BeanBoardSPI hardware
;
; Provides the ra8875.asm transport interface for BeanBoardSPI targets.
; CS and RESET are controlled via the SPI control register (SPI_CTRL).
; Data transfer is delegated to spi_byte/spi_read, which are provided
; by the linked SPI module (spi_beanboardspi_reva or spi_beanboardspi_revb).
;
; Interface (PUBLIC):
;   ra8875_reset_assert   - Assert RESET via SPI control register
;   ra8875_reset_deassert - Deassert RESET via SPI control register
;   ra8875_cs_start       - Assert SPI0 chip select
;   ra8875_cs_end         - Deassert SPI0 chip select
;   ra8875_write          - Write byte via SPI (delegates to spi_byte)
;   ra8875_read           - Read byte via SPI (delegates to spi_read)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    PUBLIC ra8875_reset_assert
    PUBLIC ra8875_reset_deassert
    PUBLIC ra8875_cs_start
    PUBLIC ra8875_cs_end
    PUBLIC ra8875_write
    PUBLIC ra8875_read

    EXTERN SPI_CTRL             ; system.asm - SPI control/status port
    EXTERN spi_byte             ; spi_beanboardspi_rev*.asm - full-duplex SPI transfer
    EXTERN spi_read             ; spi_beanboardspi_rev*.asm - receive one byte


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Control register values (active low bits)
; Bit 0: RESET, Bit 1: SPI0 CS, Bits 2-7: SPI1-SPI6 CS (all need to be set high)
RA8875_SPI_IDLE     equ 0xFF       ; all deselected, reset released
RA8875_SPI_RESET    equ 0xFE       ; bit 0 low = reset asserted
RA8875_SPI_SELECT_0 equ 0xFD       ; bit 1 low = SPI0 selected


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; transport interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Assert RA8875 RESET (active low via SPI control register)
; Destroys: AF
ra8875_reset_assert:
    push af
    ld a,RA8875_SPI_RESET
    out (SPI_CTRL),a
    pop af
    ret


; Deassert RA8875 RESET (release)
; Destroys: AF
ra8875_reset_deassert:
    push af
    ld a,RA8875_SPI_IDLE
    out (SPI_CTRL),a
    pop af
    ret


; Assert SPI0 chip select
; Destroys: AF
ra8875_cs_start:
    push af
    ld a,RA8875_SPI_SELECT_0
    out (SPI_CTRL),a
    pop af
    ret


; Deassert SPI0 chip select
; Destroys: AF
ra8875_cs_end:
    push af
    ld a,RA8875_SPI_IDLE
    out (SPI_CTRL),a
    pop af
    ret


; Write a byte over SPI
; Input: A = byte to send
; Destroys: AF
ra8875_write:
    jp spi_byte             ; trampoline - pure tail call, no local logic

; Read a byte over SPI (transmits 0x00, returns received byte)
; Output: A = byte received
; Destroys: AF
ra8875_read:
    jp spi_read             ; trampoline - pure tail call, no local logic
