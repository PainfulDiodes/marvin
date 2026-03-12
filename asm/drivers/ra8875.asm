;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RA8875 TFT display controller driver
;
; RA8875-specific routines common to all transport implementations.
; Link with exactly one transport module:
;   ra8875_spi.asm  - BeanBoardSPI hardware SPI (beandeck)
;   ra8875_gpio.asm - BeanBoard GPIO bit-bang SPI (beanboard)
;
; Transport interface (EXTERN - provided by transport module):
;   ra8875_reset_assert  - Assert hardware RESET
;   ra8875_reset_deassert - Deassert hardware RESET
;   ra8875_cs_start      - Assert CS with setup timing
;   ra8875_cs_end        - Deassert CS with hold timing
;   ra8875_write         - Write byte via SPI
;   ra8875_read          - Read byte via SPI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    PUBLIC ra8875_reset
    PUBLIC ra8875_write_command
    PUBLIC ra8875_write_data
    PUBLIC ra8875_read_data
    PUBLIC ra8875_read_reg
    PUBLIC ra8875_write_reg
    PUBLIC ra8875_reg_0_check
    PUBLIC ra8875_clear_window
    PUBLIC ra8875_display_on
    PUBLIC ra8875_adafruit_tft_enable
    PUBLIC ra8875_initialise
    PUBLIC ra8875_text_mode
    PUBLIC ra8875_cursor_blink
    PUBLIC ra8875_cursor_x
    PUBLIC ra8875_cursor_y
    PUBLIC ra8875_memory_read_write_command
    PUBLIC ra8875_putchar
    PUBLIC ra8875_puts

    EXTERN ra8875_reset_assert
    EXTERN ra8875_reset_deassert
    EXTERN ra8875_cs_start
    EXTERN ra8875_cs_end
    EXTERN ra8875_write
    EXTERN ra8875_read

INCLUDE "asm/drivers/ra8875.inc"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; common timing and reset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 0x0e was the minimum needed for PLLC1/2 init with a 10MHz Z80 clock
RA8875_DELAY_VAL equ 0xff

; General timing delay - chip settling after PLL init etc.
_ra8875_delay:
    push bc
    ld b,RA8875_DELAY_VAL
_ra8875_delay_loop:
    nop
    djnz _ra8875_delay_loop
    pop bc
    ret

; Hardware reset - assert RESET, delay, then deassert
ra8875_reset:
    call ra8875_reset_assert
    call _ra8875_delay
    call ra8875_reset_deassert
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
    call ra8875_cs_start
    ld a,RA8875_CMDWRITE
    call ra8875_write
    ld a,c ; recover the data to send
    call ra8875_write
    call ra8875_cs_end
    pop bc
    pop af
    ret

; Write data to RA8875
; A = data
ra8875_write_data:
    push af
    push bc
    ld c,a ; stash the data
    call ra8875_cs_start
    ld a,RA8875_DATAWRITE
    call ra8875_write
    ld a,c ; recover the data to send
    call ra8875_write
    call ra8875_cs_end
    pop bc
    pop af
    ret

; read data from RA8875
; returns data in A
ra8875_read_data:
    push bc
    call ra8875_cs_start
    ld a,RA8875_DATAREAD
    call ra8875_write
    call ra8875_read
    ld b,a ; stash data
    call ra8875_cs_end
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

_ra8875_pllc1_init:
    push af
    push bc
    ld a,RA8875_PLLC1
    ld b,RA8875_PLLC1_VAL
    call ra8875_write_reg
    call _ra8875_delay
    pop bc
    pop af
    ret

_ra8875_pllc2_init:
    push af
    push bc
    ld a,RA8875_PLLC2
    ld b,RA8875_PLLC2_VAL
    call ra8875_write_reg
    call _ra8875_delay
    pop bc
    pop af
    ret

_ra8875_sysr_init:
    push af
    push bc
    ld a,RA8875_SYSR
    ld b,RA8875_SYSR_16BPP | RA8875_SYSR_MCU8
    call ra8875_write_reg
    pop bc
    pop af
    ret

_ra8875_pcsr_init:
    push af
    push bc
    ld a,RA8875_PCSR
    ld b,RA8875_PCSR_VAL
    call ra8875_write_reg
    call _ra8875_delay
    pop bc
    pop af
    ret

_ra8875_horizontal_settings_init:
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

_ra8875_vertical_settings_init:
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

_ra8875_horizontal_active_window_init:
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

_ra8875_vertical_active_window_init:
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

; Configure the full-screen scroll window and enable scrolling for both layers.
; Called once during initialisation.
_ra8875_scroll_window_init:
    push af
    push bc
    ld a,RA8875_HOFS0
    ld b,0x00
    call ra8875_write_reg       ; horizontal start low = 0
    ld a,RA8875_HOFS1
    ld b,0x00
    call ra8875_write_reg       ; horizontal start high = 0
    ld a,RA8875_SCVSTR0
    ld b,0x00
    call ra8875_write_reg       ; vertical start low = 0
    ld a,RA8875_SCVSTR1
    ld b,0x00
    call ra8875_write_reg       ; vertical start high = 0
    ld a,RA8875_HEND0
    ld b,0x1F
    call ra8875_write_reg       ; horizontal end low (799 = 0x031F)
    ld a,RA8875_HEND1
    ld b,0x03
    call ra8875_write_reg       ; horizontal end high
    ld a,RA8875_VEND0
    ld b,0xDF
    call ra8875_write_reg       ; vertical end low (479 = 0x01DF)
    ld a,RA8875_VEND1
    ld b,0x01
    call ra8875_write_reg       ; vertical end high
    ld a,RA8875_SCROLL_MODE
    ld b,0x00
    call ra8875_write_reg       ; scroll mode: scroll both layers
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
_ra8875_backlight_init:
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

    call _ra8875_pllc1_init
    call ra8875_reg_0_check
    ret nz ; error

    call _ra8875_pllc2_init
    call ra8875_reg_0_check
    ret nz ; error

    call _ra8875_sysr_init

    call _ra8875_pcsr_init
    call ra8875_reg_0_check
    ret nz ; error

    call _ra8875_horizontal_settings_init
    call _ra8875_vertical_settings_init
    call _ra8875_horizontal_active_window_init
    call _ra8875_vertical_active_window_init
    call ra8875_clear_window
    call _ra8875_scroll_window_init

    call ra8875_display_on
    call ra8875_adafruit_tft_enable
    call _ra8875_backlight_init
    call ra8875_text_mode
    ld a,RA8875_CURSOR_BLINK_RATE
    call ra8875_cursor_blink

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
