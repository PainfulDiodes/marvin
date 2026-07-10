;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ra8875_beanboard.asm - RA8875 bit-bang SPI transport for BeanBoard
;
; TODO: wire up as the RA8875 transport for the beanboard target.
; BeanBoard does not have hardware SPI; this implementation bit-bangs
; the SPI protocol over the BeanBoard GPIO port (GPIO_OUT/GPIO_IN).
;
; Pin assignments on GPIO port:
;   Bit 0 (GPO): SCK
;   Bit 1 (GPO): MOSI
;   Bit 2 (GPO): RESET (active low)
;   Bit 3 (GPO): CS (active low)
;   Bit 0 (GPI): MISO
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

    EXTERN GPIO_OUT             ; system.asm - GPIO port for bit-bang SPI


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RA8875_GPO_BIT_SCK   equ 0
RA8875_GPO_BIT_MOSI  equ 1
RA8875_GPO_BIT_RESET equ 2
RA8875_GPO_BIT_CS    equ 3
RA8875_GPI_BIT_MISO  equ 0

; RESET low (active), CS high (inactive)
RA8875_GPO_RESET_STATE      equ 1 << RA8875_GPO_BIT_CS
; RESET high (inactive), CS high (inactive)
RA8875_GPO_INACTIVE_STATE   equ 1 << RA8875_GPO_BIT_CS | 1 << RA8875_GPO_BIT_RESET
; RESET high (inactive), CS low (active)
RA8875_GPO_ACTIVE_STATE     equ 1 << RA8875_GPO_BIT_RESET
; RESET high (inactive), CS low (active), MOSI low
RA8875_GPO_LOW_STATE        equ 1 << RA8875_GPO_BIT_RESET
; RESET high (inactive), CS low (active), MOSI high
RA8875_GPO_HIGH_STATE       equ 1 << RA8875_GPO_BIT_MOSI | 1 << RA8875_GPO_BIT_RESET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; transport interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Assert RA8875 RESET (active low via GPIO)
; Destroys: AF
ra8875_reset_assert:
    push af
    ld a,RA8875_GPO_RESET_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Deassert RA8875 RESET (release)
; Destroys: AF
ra8875_reset_deassert:
    push af
    ld a,RA8875_GPO_INACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Assert chip select (CS active/low)
; Destroys: AF
ra8875_cs_start:
    push af
    ld a,RA8875_GPO_ACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Deassert chip select (CS inactive/high)
; Destroys: AF
ra8875_cs_end:
    push af
    ld a,RA8875_GPO_INACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Write a byte over bit-bang SPI (MSB first)
; Input: A = byte to send
; Destroys: AF, B, D
ra8875_write:
    ld b,8
_ra8875_write_loop:
    rlca
    ld d,a
    ld a,RA8875_GPO_LOW_STATE
    jr nc,_ra8875_write_bit
    ld a,RA8875_GPO_HIGH_STATE
_ra8875_write_bit:
    out (GPIO_OUT),a
    or 1 << RA8875_GPO_BIT_SCK
    out (GPIO_OUT),a
    and ~(1 << RA8875_GPO_BIT_SCK)
    out (GPIO_OUT),a
    ld a,d
    djnz _ra8875_write_loop
    ret


; Read a byte over bit-bang SPI (MSB first, sends 0x00 dummy)
; Output: A = byte received
; Destroys: AF, B, D
ra8875_read:
    ld b,8
    ld a,0
_ra8875_read_loop:
    sla a
    ld d,a
    ld a,RA8875_GPO_LOW_STATE
    out (GPIO_OUT),a
    or 1 << RA8875_GPO_BIT_SCK
    out (GPIO_OUT),a
    in a,(GPIO_OUT)
    bit RA8875_GPI_BIT_MISO,a
    jr z,_ra8875_read_low
    ld a,d
    or 1
    jr _ra8875_read_bit_done
_ra8875_read_low:
    ld a,d
_ra8875_read_bit_done:
    ld d,a
    ld a,RA8875_GPO_LOW_STATE
    out (GPIO_OUT),a
    ld a,d
    djnz _ra8875_read_loop
    ret
