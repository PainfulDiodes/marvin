org 0x9000
MARVIN equ 0               ; MARVIN start address
UM245R_DATA equ 1          ; serial data port

start:
    ld hl,message
puts:
    ld a,(hl)
    cp 0
    jr z, end
    out(UM245R_DATA),a
    inc hl
    jp puts
end:
    jp MARVIN

message: 
    db " \n"
    db "      * * * * * * *      \n"
    db "    *               *    \n"
    db "  *                   *  \n"
    db " *      *       *      * \n"
    db "*                       *\n"
    db "*                       *\n"
    db "*                       *\n"
    db " *    *           *    * \n"
    db "  *     * * * * *     *  \n"
    db "    *               *    \n"
    db "      * * * * * * *      \n"
    db " \n",0
