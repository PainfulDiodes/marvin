;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ra8875_beanboardspi.asm - RA8875 SPI transport for BeanBoardSPI hardware
;
; Low-level SPI transport for ra8875.asm.
; Written for BeanBoardSPI: hardware SPI interface with a status register
; (bit 0 = ~SER_EN) that signals when serialisation is complete.
;
; Interface (PUBLIC):
;   ra8875_reset_assert   - Assert RESET via SPI control register
;   ra8875_reset_deassert - Deassert RESET via SPI control register
;   ra8875_cs_start       - Assert SPI0 chip select
;   ra8875_cs_end         - Deassert SPI0 chip select
;   ra8875_write          - Write byte via hardware SPI, polling for completion
;   ra8875_read           - Read byte via hardware SPI, polling for completion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    PUBLIC ra8875_reset_assert
    PUBLIC ra8875_reset_deassert
    PUBLIC ra8875_cs_start
    PUBLIC ra8875_cs_end
    PUBLIC ra8875_write
    PUBLIC ra8875_read

    EXTERN SPI_CTRL             ; system.asm - SPI control/status port
    EXTERN SPI_DATA             ; system.asm - SPI data port


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Control register values (active low bits)
; Bit 0: RESET, Bit 1: SPI0 CS, Bits 2-7: SPI1-SPI6 CS (all need to be set high)
RA8875_SPI_IDLE     equ 0xFF       ; all deselected, reset released
RA8875_SPI_RESET    equ 0xFE       ; bit 0 low = reset asserted
RA8875_SPI_SELECT_0 equ 0xFD       ; bit 1 low = SPI0 selected

; Status register (read from same port as control register)
SPI_STAT_READY      equ 0x01       ; bit 0 (~SER_EN): high = serialisation complete


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


; Write a byte over hardware SPI, poll status register for completion
; Input: A = byte to send
; Destroys: AF
ra8875_write:
    out (SPI_DATA),a
_ra8875_write_wait:
    in a,(SPI_CTRL)
    bit 0,a
    jr z,_ra8875_write_wait     ; bit 0 low = serialising
    ret


; Read a byte over hardware SPI, poll status register for completion
; Sends a dummy byte (0x00) to clock in the response
; Output: A = byte received
; Destroys: AF
ra8875_read:
    ld a,0x00
    out (SPI_DATA),a
_ra8875_read_wait:
    in a,(SPI_CTRL)
    bit 0,a
    jr z,_ra8875_read_wait      ; bit 0 low = serialising
    in a,(SPI_DATA)
    ret
