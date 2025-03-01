; escape character constants for assembler compatibility
; sjasmplus requires double quotes around escape sequences: "\n" and would not interpret '\n' but truncate
; z88dk-z80asm requires single quotes around so would correctly interpret '\n' but reject "\n"

_b equ 0x08
_t equ 0x09
_n equ 0x0a
_r equ 0x0d
_e equ 0x1b
