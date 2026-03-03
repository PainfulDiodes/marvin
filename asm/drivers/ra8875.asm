;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; delay

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
; low level utilities
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; low level RA8875 SPI routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; basic RA8875 routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Write a command to RA8875
; A = command parameter
ra8875_write_command:
    push af
    push bc
    ld c,a ; stash the data
    ld a,SPI_SELECT_0
    out (SPI_CTRL),a
    call _spi_cs_delay
    ld a,RA8875_CMDWRITE
    call _ra8875_write
    ld a,c ; recover the data to send
    call _ra8875_write
    call _spi_cs_delay
    ld a,SPI_IDLE
    out (SPI_CTRL),a
    pop bc
    pop af
    ret

; Write data to RA8875
; A = data
ra8875_write_data:
    push af
    push bc
    ld c,a ; stash the data
    ld a,SPI_SELECT_0
    out (SPI_CTRL),a
    call _spi_cs_delay
    ld a,RA8875_DATAWRITE
    call _ra8875_write
    ld a,c ; recover the data to send
    call _ra8875_write
    call _spi_cs_delay
    ld a,SPI_IDLE
    out (SPI_CTRL),a
    pop bc
    pop af
    ret

; read data from RA8875
; returns data in A
ra8875_read_data:
    push bc
    ld a,SPI_SELECT_0
    out (SPI_CTRL),a
    call _spi_cs_delay
    ld a,RA8875_DATAREAD
    call _ra8875_write
    call _ra8875_read
    ld b,a ; stash data
    call _spi_cs_delay
    ld a,SPI_IDLE
    out (SPI_CTRL),a
    ld a,b ; restore data
    pop bc
    ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ra8875 register access routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; read from RA8875 register
; A = register number to read
ra8875_read_reg:
    call ra8875_write_command
    call ra8875_read_data
    ret

; A = register number
; B = data
ra8875_write_reg:
    push af
    call ra8875_write_command ; A = register number
    ld a,b
    call ra8875_write_data
    pop af
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; higher level RA8875 routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Check RA8875 register 0 for expected value
; Z flag set if matched, reset if not  
; destroys A
ra8875_reg_0_check:
    ld a,0x00 ; register number
    call ra8875_read_reg
    cp RA8875_REG_0_VAL ; sets Z flag if matched
    ret

ra8875_pllc1_init:
    push af
    push bc
    ld a,RA8875_PLLC1
    ld b,RA8875_PLLC1_VAL
    call ra8875_write_reg
    call ra8875_delay
    pop bc
    pop af
    ret

ra8875_pllc2_init:
    push af
    push bc
    ld a,RA8875_PLLC2
    ld b,RA8875_PLLC2_VAL
    call ra8875_write_reg
    call ra8875_delay
    pop bc
    pop af
    ret

ra8875_sysr_init:
    push af
    push bc
    ld a,RA8875_SYSR
    ld b,RA8875_SYSR_16BPP | RA8875_SYSR_MCU8
    call ra8875_write_reg
    pop bc
    pop af
    ret

ra8875_pcsr_init:
    push af
    push bc
    ld a,RA8875_PCSR
    ld b,RA8875_PCSR_VAL
    call ra8875_write_reg
    call ra8875_delay
    pop bc
    pop af
    ret

ra8875_horizontal_settings_init:
    push af
    push bc
    ld a,RA8875_HDWR
    ld b,RA8875_HDWR_VAL
    call ra8875_write_reg
    ld a,RA8875_HNDFTR
    ld b,RA8875_HNDFTR_VAL
    call ra8875_write_reg
    ld a,RA8875_HNDR
    ld b,RA8875_HNDR_VAL
    call ra8875_write_reg
    ld a,RA8875_HSTR
    ld b,RA8875_HSTR_VAL
    call ra8875_write_reg
    ld a,RA8875_HPWR
    ld b,RA8875_HPWR_VAL
    call ra8875_write_reg
    pop bc
    pop af
    ret

ra8875_vertical_settings_init:
    push af
    push bc
    ld a,RA8875_VDHR0
    ld b,RA8875_VDHR0_VAL
    call ra8875_write_reg
    ld a,RA8875_VDHR1
    ld b,RA8875_VDHR1_VAL
    call ra8875_write_reg
    ld a,RA8875_VNDR0
    ld b,RA8875_VNDR0_VAL
    call ra8875_write_reg   
    ld a,RA8875_VNDR1
    ld b,RA8875_VNDR1_VAL
    call ra8875_write_reg
    ld a,RA8875_VSTR0
    ld b,RA8875_VSTR0_VAL
    call ra8875_write_reg
    ld a,RA8875_VSTR1
    ld b,RA8875_VSTR1_VAL
    call ra8875_write_reg
    ld a,RA8875_VPWR
    ld b,RA8875_VPWR_VAL
    call ra8875_write_reg
    pop bc
    pop af
    ret

ra8875_horizontal_active_window_init:
    push af
    push bc
    ld a,RA8875_HSAW0
    ld b,RA8875_HSAW0_VAL
    call ra8875_write_reg
    ld a,RA8875_HSAW1
    ld b,RA8875_HSAW1_VAL
    call ra8875_write_reg
    ld a,RA8875_HEAW0
    ld b,RA8875_HEAW0_VAL
    call ra8875_write_reg
    ld a,RA8875_HEAW1
    ld b,RA8875_HEAW1_VAL
    call ra8875_write_reg
    pop bc
    pop af
    ret

ra8875_vertical_active_window_init:
    push af
    push bc
    ld a,RA8875_VSAW0
    ld b,RA8875_VSAW0_VAL
    call ra8875_write_reg
    ld a,RA8875_VSAW1
    ld b,RA8875_VSAW1_VAL
    call ra8875_write_reg
    ld a,RA8875_VEAW0
    ld b,RA8875_VEAW0_VAL
    call ra8875_write_reg
    ld a,RA8875_VEAW1
    ld b,RA8875_VEAW1_VAL
    call ra8875_write_reg
    pop bc
    pop af
    ret

ra8875_clear_window:
    push af
    push bc
    ld a,RA8875_MCLR
    ld b,RA8875_MCLR_START | RA8875_MCLR_FULL
    call ra8875_write_reg
    ; wait for clear to complete
_ra8875_clear_wait:
    call ra8875_read_reg
    cp RA8875_MCLR_READSTATUS
    jr z,_ra8875_clear_wait
    pop bc
    pop af
    ret

ra8875_display_on:
    push af
    push bc
    ld a,RA8875_PWRR
    ld b,RA8875_PWRR_NORMAL | RA8875_PWRR_DISPON
    call ra8875_write_reg
    pop bc
    pop af
    ret

; GPIOX wired to enable TFT display
ra8875_adafruit_tft_enable:
    push af
    push bc
    ld a,RA8875_GPIOX
    ld b,0x01
    call ra8875_write_reg
    pop bc
    pop af
    ret

; PWM1 wired for backlight control
ra8875_backlight_init:
    push af
    push bc
    ld a,RA8875_P1CR
    ld b,RA8875_P1CR_VAL
    call ra8875_write_reg
    ld a,RA8875_P1DCR
    ld b,0xff
    call ra8875_write_reg
    pop bc
    pop af
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; top level RA8875 routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ra8875_initialise:
    call ra8875_reset
    call ra8875_reg_0_check
    ret nz ; error

    call ra8875_pllc1_init
    call ra8875_reg_0_check
    ret nz ; error

    call ra8875_pllc2_init
    call ra8875_reg_0_check
    ret nz ; error

    call ra8875_sysr_init

    call ra8875_pcsr_init
    call ra8875_reg_0_check
    ret nz ; error

    call ra8875_horizontal_settings_init
    call ra8875_vertical_settings_init
    call ra8875_horizontal_active_window_init
    call ra8875_vertical_active_window_init
    call ra8875_clear_window

    call ra8875_display_on
    call ra8875_adafruit_tft_enable
    call ra8875_backlight_init

    cmp a ; clear error flag
    ret

; TODO this could be simpler if we just need to initialise for text mode
ra8875_text_mode:
    push af
    ; Set text mode
    ld a,RA8875_MWCR0
    call ra8875_write_command
    call ra8875_read_data
    or RA8875_MWCR0_TXTMODE ; set text mode bit
    call ra8875_write_data
    ; Select the internal (ROM) font
    ld a,RA8875_FNCR0
    call ra8875_write_command
    call ra8875_read_data
    and 0b01011111 ; Clear bits 7 and 5
    call ra8875_write_data
    pop af
    ret

; TODO compress/rationalise this function and check it still works!
; A = blink rate (0-255)
ra8875_cursor_blink:
    push af
    push bc
    ld b,a ; stash blink rate in B
    ld a,RA8875_MWCR0
    call ra8875_write_command
    call ra8875_read_data
    or RA8875_MWCR0_CURSOR ; set cursor visible bit
    call ra8875_write_data

    ld a,RA8875_MWCR0
    call ra8875_write_command
    call ra8875_read_data
    or RA8875_MWCR0_BLINK ; set blink bit
    call ra8875_write_data

    ld a,RA8875_BTCR
    call ra8875_write_command
    ld a,b ; restore blink rate
    call ra8875_write_data
    pop bc
    pop af
    ret

; HL = x position
ra8875_cursor_x:
    push af
    push hl
    ld a,RA8875_F_CURXL
    call ra8875_write_command
    ld a,l
    call ra8875_write_data
    ld a,RA8875_F_CURXH
    call ra8875_write_command
    ld a,h
    call ra8875_write_data
    pop hl
    pop af
    ret

; HL = y position
ra8875_cursor_y:
    push af
    push hl
    ld a,RA8875_F_CURYL
    call ra8875_write_command
    ld a,l
    call ra8875_write_data
    ld a,RA8875_F_CURYH
    call ra8875_write_command
    ld a,h
    call ra8875_write_data
    pop hl
    pop af
    ret

ra8875_memory_read_write_command:
    push af
    ld a,RA8875_MRWC
    call ra8875_write_command
    pop af
    ret

; A = character to write
ra8875_putchar:
    push af
    push bc
    ld b,a ; stash char in B
    ld a,RA8875_MRWC
    call ra8875_write_command
    ld a,b ; restore char to A
    call ra8875_write_data
    pop bc
    pop af
    ret

; HL = pointer to null-terminated string
; TODO could be improved by calling ra8875_write_data directly
ra8875_puts:
    push af
    push bc
_ra8875_puts_loop:
    ld a,(hl)
    cp 0
    jr z,_ra8875_puts_done
    call ra8875_putchar
    inc hl
    jr _ra8875_puts_loop
_ra8875_puts_done:
    pop bc
    pop af
    ret