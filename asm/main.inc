; start of user RAM
RAMSTART equ 0x8000

; 8-byte status area
CONSOLE_STATUS equ 0xf000
; 8-byte keyscan buffer
KEY_MATRIX_BUFFER equ 0xf010
; command buffer
CMD_BUFFER equ 0xf020
; this should really be 0x0000 as the CPU will dec SP before PUSH
STACK equ 0xffff

UM245R_CTRL equ 0 ; serial control port
UM245R_DATA equ 1 ; serial data port
KEYSCAN_OUT equ 2 ; either 2 or 3 will work
KEYSCAN_IN  equ 3 ; either 2 or 3 will work
LCD_CTRL    equ 4 ; LCD control port
LCD_DATA    equ 5 ; LCD data port
GPIO_OUT    equ 6 ; either 6 or 7 will work
GPIO_IN     equ 7 ; either 6 or 7 will work

CONSOLE_STATUS_USB equ 1
CONSOLE_STATUS_BEANBOARD equ 2
