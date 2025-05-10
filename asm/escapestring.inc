; escape character constants for assembler compatibility
; sjasmplus requires double quotes around escape sequences: "\n" and would not interpret '\n' but truncate
; z88dk-z80asm requires single quotes around so would correctly interpret '\n' but reject "\n"

ESC_B equ 0x08 ; \b
ESC_T equ 0x09 ; \t
ESC_N equ 0x0a ; \n
ESC_R equ 0x0d ; \r
ESC_E equ 0x1b ; \e
SLASH equ 0x5c ; \\
QUOTE equ 0x27 ; \'
