IFNDEF _JUMPTABLE_INC
DEFINE _JUMPTABLE_INC

; Marvin jump table - fixed ROM addresses
; Each entry is a 3-byte JP instruction
; Consumers call these addresses for Marvin I/O services
;
; Must match the jump table in entry_<target>.asm / entry_<target>_minimal.asm

MARVIN_COLDSTART    EQU 0x0010
MARVIN_WARMSTART    EQU 0x0013
MARVIN_PUTCHAR      EQU 0x0016
MARVIN_GETCHAR      EQU 0x0019
MARVIN_READCHAR     EQU 0x001C
MARVIN_PUTS         EQU 0x001F
MARVIN_PUTCHAR_HEX  EQU 0x0022
MARVIN_HEX_BYTE_VAL EQU 0x0025
MARVIN_LCD_INIT     EQU 0x0028
MARVIN_LCD_PUTCHAR  EQU 0x002B
MARVIN_KEY_READCHAR EQU 0x002E

ENDIF
