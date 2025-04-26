; escape character constants for assembler compatibility
; sjasmplus requires double quotes around escape sequences: "\n" and would not interpret '\n' but truncate
; z88dk-z80asm requires single quotes around so would correctly interpret '\n' but reject "\n"

ESC_B equ $08 ; \b
ESC_T equ $09 ; \t
ESC_N equ $0a ; \n
ESC_R equ $0d ; \r
ESC_E equ $1b ; \e
SLASH equ $5c ; \\
QUOTE equ $27 ; \'
