UM245R_CTRL .equ 0          ; serial control port
UM245R_DATA .equ 1          ; serial data port

    ld a, "\n"
    out  (UM245R_DATA),a
    ld a, "H"
    out  (UM245R_DATA),a
    ld a, "e"
    out  (UM245R_DATA),a
    ld a, "l"
    out  (UM245R_DATA),a
    ld a, "l"
    out  (UM245R_DATA),a
    ld a, "o"
    out  (UM245R_DATA),a
    ld a, "!"
    out  (UM245R_DATA),a
    ld a, "\n"
    out  (UM245R_DATA),a
    out  (UM245R_DATA),a
    jp 0
    