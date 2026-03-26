; Marvin system constants.
; All labels are PUBLIC so they can be referenced via EXTERN from other modules.

    PUBLIC RAMSTART
    PUBLIC CONSOLE_STATUS, KEY_MATRIX_BUFFER, CMD_BUFFER, STACK
    PUBLIC UM245R_CTRL, UM245R_DATA
    PUBLIC KEYSCAN_OUT, KEYSCAN_IN
    PUBLIC LCD_CTRL, LCD_DATA
    PUBLIC GPIO_OUT, GPIO_IN
    PUBLIC SPI_CTRL, SPI_DATA
    PUBLIC RA8875_GPIO, RA8875_SPI_CTRL, RA8875_SPI_DATA, RA8875_RAMSTART
    PUBLIC CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD

; start of user RAM
RAMSTART            equ 0x8000

; system RAM
CONSOLE_STATUS      equ 0xf000  ; console status byte
KEY_MATRIX_BUFFER   equ 0xf010  ; 8-byte keyscan buffer
CMD_BUFFER          equ 0xf020  ; command buffer
; RA8875 console variables occupy 0xe000-0xefff

; stack starts at top of RAM (CPU decrements SP before PUSH)
STACK               equ 0xffff

; USB serial (UM245R)
UM245R_CTRL         equ 0
UM245R_DATA         equ 1

; keyboard scan
KEYSCAN_OUT         equ 2       ; either 2 or 3 will work
KEYSCAN_IN          equ 3       ; either 2 or 3 will work

; LCD display (HD44780)
LCD_CTRL            equ 4
LCD_DATA            equ 5

; GPIO (bit-bang SPI for BeanBoard RA8875)
GPIO_OUT            equ 6       ; either 6 or 7 will work
GPIO_IN             equ 7       ; either 6 or 7 will work

; hardware SPI (BeanDeck BeanBoardSPI)
SPI_CTRL            equ 8       ; SPI control register (74HCT373 latch)
SPI_DATA            equ 10      ; SPI data register (74HCT299 shift register)

; RA8875 driver labels (aliases used by ra8875-z80-repo transport modules)
RA8875_GPIO         equ GPIO_OUT    ; GPIO port for RA8875 bit-bang SPI
RA8875_SPI_CTRL     equ SPI_CTRL    ; hardware SPI control port
RA8875_SPI_DATA     equ SPI_DATA    ; hardware SPI data port
RA8875_RAMSTART     equ 0xe000      ; RA8875 console variables base address

; console selection
CONSOLE_STATUS_USB       equ 1
CONSOLE_STATUS_BEANBOARD equ 2
