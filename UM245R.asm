; It is assumed that UM245R status signals are gated to the data bus as an IO port where: 
; /TXE = bit 0
; /RXF = bit 1 
; As per:
; https://github.com/PainfulDiodes/z80-breadboard-computer/tree/v1.0.0

ALIGN $10

getchar:                    ; get character and return in A

    ; TEMPORARY - test keyscan input
    call keyscan
    cp 0
    ret nz

    in a,(UM245R_CTRL)      ; get the USB status
    bit 1,a                 ; data to read? (active low)
    jr nz,getchar           ; no, the buffer is empty
    in a,(UM245R_DATA)      ; yes, read the received char
    cp _r                   ; is CR?
    ret nz                  ; no - return
    ld a, _n                ; convert CR to LF
    ret 

ALIGN $10

putchar:

    ; TEMPORARY - test LCD output
    push af
    call lcd_putchar
    pop af

    cp _n                   ; newline?
    jr nz, doputc           ; no - just send the char
    ld a, _r
    call putc
    ld a, _n
doputc:
    call putc
    ret

ALIGN $10

putc:                       ; transmit character in A
    push bc
    ld b,a                  ; save the transmit character
putcloop: 
    in a,(UM245R_CTRL)      ; get the USB status
    bit 0,a                 ; ready to transmit? (active low)
    jr nz,putcloop          ; no, bit is high
    ld a,b                  ; yes, restore the transmit character
    out  (UM245R_DATA),a    ; transmit the character
    pop bc
    ret

ALIGN $10

puts:                       ; print a zero-terminated string, pointed to by hl
    push hl
puts_loop:
    ld a,(hl)               ; get character from string
    cp 0                    ; is it zero?
    jr z, puts_end          ; yes - return
    call putchar            ; no - send character
    inc hl                  ; next character position
    jp puts_loop            ; loop for next character
puts_end:
    pop hl
    ret