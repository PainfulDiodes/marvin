; It is assumed that UM245R status signals are gated to the data bus as an IO port where: 
; /TXE = bit 0
; /RXF = bit 1 
; As per:
; https://github.com/PainfulDiodes/z80-breadboard-computer

usb_read_char:              ; get character and return in A
    in a,(UM245R_CTRL)      ; get the USB status
    bit 1,a                 ; data to read? (active low)
    jr nz,_usb_no_char      ; no, the buffer is empty
    in a,(UM245R_DATA)      ; yes, read the received char
    cp _r                   ; is CR?
    ret nz                  ; no - return
    ld a, _n                ; convert CR to LF
    ret 
_usb_no_char:
    ld a,0
    ret

; TODO
usb_has_char:               ; get character and return in A
;    in a,(UM245R_CTRL)      ; get the USB status
;    bit 1,a                 ; data to read? (active low)
;    jr nz,usb_getchar       ; no, the buffer is empty
;    in a,(UM245R_DATA)      ; yes, read the received char
;    cp _r                   ; is CR?
;    ret nz                  ; no - return
;    ld a, _n                ; convert CR to LF
    ret 

usb_putchar:
    cp _n                   ; newline?
    jr nz,_do_usb_put       ; no - just send the char
    ld a, _r
    call _usb_put
    ld a, _n
_do_usb_put:
    call _usb_put
    ret

_usb_put:                   ; transmit character in A
    push bc
    ld b,a                  ; save the transmit character
_usb_put_loop: 
    in a,(UM245R_CTRL)      ; get the USB status
    bit 0,a                 ; ready to transmit? (active low)
    jr nz,_usb_put_loop     ; no, bit is high
    ld a,b                  ; yes, restore the transmit character
    out (UM245R_DATA),a     ; transmit the character
    pop bc
    ret
