IFNDEF _MAIN_INC
DEFINE _MAIN_INC

; start of user RAM
RAMSTART equ 0x8000

; 8-byte status area
CONSOLE_STATUS equ 0xf000
RA8875_CURSOR_Y_PIX equ 0xf001  ; 2-byte RA8875 text cursor Y position (pixels)
RA8875_CURSOR_X     equ 0xf003  ; 1-byte column counter (0-99)
RA8875_CURSOR_Y     equ 0xf004  ; 1-byte logical row (0-29)
; framebuffer: 30*100 = 3000 bytes (0xf100-0xfcb7), stack above 0xfcb8
RA8875_FRAMEBUFFER equ 0xf100
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

ENDIF
