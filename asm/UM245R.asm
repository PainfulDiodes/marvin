; It is assumed that UM245R status signals are gated to the data bus as an IO port where: 
; /TXE = bit 0
; /RXF = bit 1 
; As per:
; https://github.com/PainfulDiodes/z80-breadboard-computer
; 
; line endings are translated:
; incoming line endings from the terminal are expected to be \r 
; and are tranlslated to \n
; (\r\n would count as 2 line endings)
; and outgoing line endings are sent as \r\n
; externally this is consistent with VT100/ANSI terminal behaviour
; and internally line endings are always \n

ALIGN 0x10

; get character and return in A
usb_readchar:
    ; get the USB status
    in a,(UM245R_CTRL)
    ; data to read? (active low)
    bit 1,a
    ; no, the buffer is empty
    jr nz,_usb_no_char
    ; yes, read the received char
    in a,(UM245R_DATA)
    ; is CR?
    cp ESC_R
    ; no:
    ret nz
    ; yes: convert CR to LF
    ld a, ESC_N
    ret 
_usb_no_char:
    ld a,0
    ret

ALIGN 0x10

usb_putchar:
    ; newline?
    cp ESC_N
    ; no: just send the char
    jr nz,_do_usb_put
    ld a, ESC_R
    call _usb_put
    ld a, ESC_N
_do_usb_put:
    call _usb_put
    ret

; transmit character in A
_usb_put:
    push bc
    ; stash the transmit character
    ld b,a
_usb_put_loop: 
    ; get the USB status
    in a,(UM245R_CTRL)
    ; ready to transmit? (active low)
    bit 0,a
    ; no: bit is high
    jr nz,_usb_put_loop
    ; yes: restore the stashed transmit character
    ld a,b
    ; transmit the character
    out (UM245R_DATA),a
    pop bc
    ret
