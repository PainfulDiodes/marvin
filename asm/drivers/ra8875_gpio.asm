;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RA8875 GPIO bit-bang SPI transport layer (BeanBoard GPIO)
;
; Provides the low-level SPI transport interface for ra8875_core.asm.
; Bit-bangs the SPI protocol over the BeanBoard GPIO port, with manual
; control of SCK, MOSI, MISO, CS, and RESET signals.
;
; Interface (PUBLIC):
;   ra8875_delay         - General timing delay
;   ra8875_reset         - Hardware reset via GPIO
;   _ra8875_cs_start     - Assert CS
;   _ra8875_cs_end       - Deassert CS
;   _ra8875_write        - Write byte via bit-bang SPI
;   _ra8875_read         - Read byte via bit-bang SPI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    PUBLIC ra8875_delay
    PUBLIC ra8875_reset
    PUBLIC _ra8875_cs_start
    PUBLIC _ra8875_cs_end
    PUBLIC _ra8875_write
    PUBLIC _ra8875_read

INCLUDE "asm/system.inc"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 0x0e was the minimum needed for PLLC1/2 init with a 10MHz Z80 clock
RA8875_DELAY_VAL equ 0xff

; Pin definitions for RA8875 SPI on GPIO port
; GPO
; Serial Clock
RA8875_SCK        equ 0
; Master Out Slave In
RA8875_MOSI       equ 1
; RA8875 RESET - active LOW
RA8875_RESET      equ 2
; Chip Select - active LOW
RA8875_CS         equ 3
; GPI
RA8875_WAIT       equ 0
RA8875_MISO       equ 1

; RESET active/low, CS inactive/high
GPO_RESET_STATE  equ 1 << RA8875_CS
; RESET inactive/high, CS inactive/high
GPO_INACTIVE_STATE   equ 1 << RA8875_CS | 1 << RA8875_RESET
; RESET inactive/high, CS active/low
GPO_ACTIVE_STATE equ 1 << RA8875_RESET
; RESET inactive/high, CS active/low, MOSI low
GPO_LOW_STATE    equ 1 << RA8875_RESET
; RESET inactive/high, CS active/low, MOSI high
GPO_HIGH_STATE   equ 1 << RA8875_MOSI | 1 << RA8875_RESET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; transport interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; delay
ra8875_delay:
    push bc
    ld b,RA8875_DELAY_VAL
_ra8875_delay_loop:
    nop
    djnz _ra8875_delay_loop
    pop bc
    ret


; hardware reset of RA8875
ra8875_reset:
    push af
    ld a,GPO_RESET_STATE
    out (GPIO_OUT),a
    call ra8875_delay
    ld a,GPO_INACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Assert chip select (CS active/low)
; No setup delay required - bit-bang timing is sufficient
; Destroys: AF
_ra8875_cs_start:
    push af
    ld a,GPO_ACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Deassert chip select (CS inactive/high)
; Destroys: AF
_ra8875_cs_end:
    push af
    ld a,GPO_INACTIVE_STATE
    out (GPIO_OUT),a
    pop af
    ret


; Write a byte over SPI without readback
; Input: A = byte to send
; Destroys: AF, B, D
_ra8875_write:
    ; bit counter
    ld b,8
_ra8875_write_loop:
    ; rotate msb into carry flag
    rlca
    ; stash a
    ld d,a
    ; default to MOSI low
    ld a,GPO_LOW_STATE
    jr nc,_ra8875_write_bit
    ld a,GPO_HIGH_STATE
_ra8875_write_bit:
    out (GPIO_OUT),a
    ; clock high
    or 1 << RA8875_SCK
    out (GPIO_OUT),a
    ; clock low
    and ~(1 << RA8875_SCK)
    out (GPIO_OUT),a
    ; restore A
    ld a,d
    djnz _ra8875_write_loop
    ret


; Read a byte over SPI (receive from MISO)
; Sends a dummy byte (0x00) during the read
; Output: A = byte received
; Destroys: AF, B, D
_ra8875_read:
    ; bit counter
    ld b,8
    ; Initialize received byte
    ld a,0
_ra8875_read_loop:
    ; Shift received bits left
    sla a
    ; stash a
    ld d,a
    ; Set initial low state
    ld a,GPO_LOW_STATE
    out (GPIO_OUT),a
    ; Set clock high
    or 1 << RA8875_SCK
    out (GPIO_OUT),a
    ; Read MISO bit
    in a,(GPIO_IN)
    bit RA8875_MISO,a
    jr z,_ra8875_read_low
    ; MISO high - set LSB
    ld a,d
    or 1
    jr _ra8875_read_bit_done
_ra8875_read_low:
    ; MISO low - keep LSB clear
    ld a,d
_ra8875_read_bit_done:
    ; Set clock low
    ld d,a
    ld a,GPO_LOW_STATE
    out (GPIO_OUT),a
    ; Restore received byte
    ld a,d
    djnz _ra8875_read_loop
    ret
