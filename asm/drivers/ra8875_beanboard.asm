;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ra8875_beanboard.asm - RA8875 bit-bang SPI transport for BeanBoard
;
; TODO: wire up as the RA8875 transport for the beanboard target.
; BeanBoard does not have hardware SPI; this implementation bit-bangs
; the SPI protocol over the BeanBoard GPIO port (GPIO_OUT/GPIO_IN).
;
; Pin assignments: see asm/drivers/beanboard.inc
;
; Interface (PUBLIC):
;   ra8875_reset_assert   - Assert RESET via GPIO
;   ra8875_reset_deassert - Deassert RESET via GPIO
;   ra8875_cs_start       - Assert CS via GPIO
;   ra8875_cs_end         - Deassert CS via GPIO
;   ra8875_write          - Write byte via bit-bang SPI
;   ra8875_read           - Read byte via bit-bang SPI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    PUBLIC ra8875_reset_assert
    PUBLIC ra8875_reset_deassert
    PUBLIC ra8875_cs_start
    PUBLIC ra8875_cs_end
    PUBLIC ra8875_write
    PUBLIC ra8875_read

    EXTERN GPIO_OUT             ; system.asm - GPIO output port
    EXTERN spi_byte             ; spi_beanboard.asm - full-duplex SPI transfer
    EXTERN spi_read             ; spi_beanboard.asm - receive one byte


    INCLUDE "asm/drivers/beanboard.inc"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; transport interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Assert RA8875 RESET (active low via GPIO)
; Destroys: AF
ra8875_reset_assert:
    push af
    ld a,GPO_RESET_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Deassert RA8875 RESET (release)
; Destroys: AF
ra8875_reset_deassert:
    push af
    ld a,GPO_INACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Assert chip select (CS active/low)
; Destroys: AF
ra8875_cs_start:
    push af
    ld a,GPO_ACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Deassert chip select (CS inactive/high)
; Destroys: AF
ra8875_cs_end:
    push af
    ld a,GPO_INACTIVE_STATE
    out (GPIO_OUT),a
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
