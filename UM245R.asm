; It is assumed that UM245R status signals are gated to the data bus as an IO port where: 
; /TXE = bit 0
; /RXF = bit 1 
; As per:
; https://github.com/PainfulDiodes/z80-breadboard-computer/tree/v1.0.0

getchar:                    ; get character from the UM245E and return in A
    in a,(UM245R_CTRL)      ; get the USB status
    bit 1,a                 ; data to read? (active low)
    jr nz,getchar           ; no, the buffer is empty
    in a,(UM245R_DATA)      ; yes, read the received char
    ret 

putchar:                    ; transmit character in A via the UM245E 
    push bc
    ld b,a                  ; save the transmit character
putcharloop: 
    in a,(UM245R_CTRL)      ; get the USB status
    bit 0,a                 ; ready to transmit? (active low)
    jr nz,putcharloop       ; no, bit is high
    ld a,b                  ; yes, restore the transmit character
    out  (UM245R_DATA),a    ; transmit the character
    pop bc
    ret

puts:                       ; print a zero-terminated string, pointed to by hl
    push hl
puts_loop:
    ld a,(hl)               ; get character from string
    cp 0                    ; is it zero?
    jr z, puts_end          ; yes - return
    out(UM245R_DATA),a      ; no - send character
    inc hl                  ; next character position
    jp puts_loop            ; loop for next character
puts_end:
    pop hl
    ret