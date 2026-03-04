;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RA8875 SPI transport layer (BeanBoardSPI hardware)
;
; Provides the low-level SPI transport interface for ra8875_core.asm.
; Uses the BeanBoardSPI expansion board: 74HCT299 shift register for
; serialisation and 74HCT373 latch for chip select and reset control.
;
; Interface (PUBLIC):
;   ra8875_delay         - General timing delay
;   ra8875_reset         - Hardware reset via control register
;   _ra8875_cs_start     - Assert CS with setup delay
;   _ra8875_cs_end       - Deassert CS with hold delay
;   _ra8875_write        - Write byte via hardware SPI
;   _ra8875_read         - Read byte via hardware SPI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    PUBLIC ra8875_delay
    PUBLIC ra8875_reset
    PUBLIC _ra8875_cs_start
    PUBLIC _ra8875_cs_end
    PUBLIC _ra8875_write
    PUBLIC _ra8875_read


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 0x0e was the minimum needed for PLLC1/2 init with a 10MHz Z80 clock
RA8875_DELAY_VAL equ 0xff

; SPI ports (BeanBoardSPI hardware)
SPI_CTRL        equ 8       ; control register (74HCT373 latch)
SPI_DATA        equ 10      ; data register (74HCT299 shift register)

; Control register values (active low bits)
; Bit 0: RESET, Bit 1: SPI0 CS, Bits 2-7: SPI1-SPI6 CS
SPI_IDLE        equ 0xFF    ; all deselected, reset released
SPI_RESET       equ 0xFE    ; bit 0 low = reset asserted
SPI_SELECT_0    equ 0xFD    ; bit 1 low = SPI0 selected

; Serialisation delay - time for 74HCT299 to shift 8 bits
SPI_SERIAL_DELAY equ 0xff

; CS setup/hold delay - loop count after asserting or before deasserting CS
SPI_CS_DELAY_VAL equ 0xff


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; internal utilities
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; CS setup/hold delay - called after asserting and before deasserting CS
_spi_cs_delay:
    push bc
    ld b,SPI_CS_DELAY_VAL
_spi_cs_delay_loop:
    nop
    djnz _spi_cs_delay_loop
    pop bc
    ret


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
    ld a,SPI_RESET
    out (SPI_CTRL),a
    call ra8875_delay
    ld a,SPI_IDLE
    out (SPI_CTRL),a
    pop af
    ret


; Assert SPI0 chip select with setup delay
; Destroys: AF
_ra8875_cs_start:
    push af
    ld a,SPI_SELECT_0
    out (SPI_CTRL),a
    call _spi_cs_delay
    pop af
    ret


; Deassert SPI0 chip select with hold delay
; Destroys: AF
_ra8875_cs_end:
    push af
    call _spi_cs_delay
    ld a,SPI_IDLE
    out (SPI_CTRL),a
    pop af
    ret


; Write a byte over hardware SPI
; Input: A = byte to send
; Destroys: AF, B
_ra8875_write:
    out (SPI_DATA),a
    push bc
    ld b,SPI_SERIAL_DELAY
_ra8875_write_delay:
    nop
    djnz _ra8875_write_delay
    pop bc
    ret


; Read a byte over hardware SPI
; Sends a dummy byte (0x00) to clock in the response
; Output: A = byte received
; Destroys: AF, B
_ra8875_read:
    ld a,0x00
    out (SPI_DATA),a
    push bc
    ld b,SPI_SERIAL_DELAY
_ra8875_read_delay:
    nop
    djnz _ra8875_read_delay
    pop bc
    in a,(SPI_DATA)
    ret
