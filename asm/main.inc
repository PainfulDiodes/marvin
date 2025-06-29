; start of user RAM
RAMSTART equ 0x8000

SYSRAM equ 0xf000

; status area (16 bytes allocated, 1 used)
; only used on beanboard - TODO candidate for conditional assembly
CONSOLE_STATUS equ SYSRAM
CONSOLE_STATUS_SIZE equ 0x10

; buffer (16 bytes allocated, 8 used)
; only used on beanboard - TODO candidate for conditional assembly
KEY_MATRIX_BUFFER equ SYSRAM+CONSOLE_STATUS_SIZE
KEY_MATRIX_BUFFER_SIZE equ 0x10

; BeanBoard LCD buffer - same size as display, but has the potential to expand and support scrolling
; only used on beanboard - TODO candidate for conditional assembly
LCD_BUFFER equ KEY_MATRIX_BUFFER+KEY_MATRIX_BUFFER_SIZE

; command buffer
CMD_BUFFER equ LCD_BUFFER+LCD_BUFFER_LEN

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

; CONSOLE_STATUS values
CONSOLE_STATUS_USB equ 1
CONSOLE_STATUS_BEANBOARD equ 2
