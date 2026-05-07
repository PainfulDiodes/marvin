; string.asm - string and display utility functions

    PUBLIC con_print_decimal

    EXTERN con_putchar

; con_print_decimal: print byte A as decimal digits (0-255), no leading zeros
; in:  A = value
; out: —
; destroys: AF, BC
con_print_decimal:
    push af
    push bc
    ld b, 0                     ; hundreds digit
    ld c, 0                     ; tens digit
_cpd_hundreds:
    cp 100
    jr c, _cpd_tens
    sub 100
    inc b
    jr _cpd_hundreds
_cpd_tens:
    cp 10
    jr c, _cpd_units
    sub 10
    inc c
    jr _cpd_tens
_cpd_units:
    push af                     ; save units digit
    ld a, b
    or a
    jr z, _cpd_no_hundreds
    add a, '0'
    call con_putchar            ; hundreds
    ld a, c
    add a, '0'
    call con_putchar            ; tens (always printed if hundreds printed)
    jr _cpd_print_units
_cpd_no_hundreds:
    ld a, c
    or a
    jr z, _cpd_print_units
    add a, '0'
    call con_putchar            ; tens
_cpd_print_units:
    pop af
    add a, '0'
    call con_putchar            ; units
    pop bc
    pop af
    ret
