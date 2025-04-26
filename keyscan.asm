DEBOUNCE_DELAY equ $f0
MOD_KEY_SHIFT_L equ %00000010
MOD_KEY_SHIFT_R equ %00000001

; initialise keyscan
keyscan_init:
    push bc
    push hl
    ld b,8
    ld hl,KEYSCAN_BUFFER
_keyscan_init_loop:
    ld (hl),0
    inc hl
    djnz _keyscan_init_loop
    ; end
    pop hl
    pop bc
    ret

; return value in A
keyscan:
    push bc
    push de
    push hl
    ; initial row bit - only 1 bit is ever set at a time - it is shifted from bit 0 to bit 7
    ld b,$01                    
    ; row counter - 0 => 7
    ld c,$00                    
    ; location of previous values
    ld hl,KEYSCAN_BUFFER
    call _modifierkeys
    ; initialise map pointer
    ld de,QWERTY_KEYMAP_L
    ; either shift key down?
    and MOD_KEY_SHIFT_L+MOD_KEY_SHIFT_R
    jp z,_keyscanloop
    ld de,QWERTY_KEYMAP_U
_keyscanloop:
    call _rowscan
    ; ASCII returned in A, or 0
    call _colscan 
    cp 0
    jp nz,_delay
    ; move the pointer of previous values to the next row slot
    inc hl                      
    ; increment row counter
    inc c                       
    ; clear the carry flag
    or a                        
    ; shift row bit left - when we've done all 8, it will move to the carry flag
    rl b                        
    ; loop if not done all rows
    jr nc,_keyscanloop          
    ; key debounce
_delay:                         
    ; set a to the length of the delay
    ld b,DEBOUNCE_DELAY         
_delayloop:                      
    ; wait a few cycles
    nop                         
    ; no - loop again
    djnz _delayloop             
; end
    pop hl
    pop de
    pop bc
    ret

; get row bitmap representing new keystrokes:  
; B contains row bit,
; C contains row count,
; HL contains a pointer to the old value.
; return value in A
_rowscan:                       
    ; preserve registers
    push de                     
    ; fetch previous value for comparison
    ld a,(hl)                   
    ; invert A - we want to check keys becoming closed - so zeroed bits on the previous value are significant
    cpl                         
    ; store inverted previous value
    ld d,a                      
    ; get the current row bit
    ld a,b                      
    ; output row strobe
    out (KEYSCAN_OUT),a            
    ; get column values
    in a,(KEYSCAN_IN)             
    ; store the new value
    ld (hl),a                   
    ; newVal AND ~oldVal means bits are set only when the previous bit value was 0
    and d                       
    ; restore registers
    pop de                      
    ret

; get bitmap representing modifier keys:  
; return value in A
_modifierkeys:                       
    ld a,%01000000 ; row 7
    ; output row strobe
    out (KEYSCAN_OUT),a            
    ; get column values
    in a,(KEYSCAN_IN)
    and %00000001 ; row 7, bit 1 is LEFT SHIFT
    ; left shift modifier
    jr nz,_modifier_l_shift
    ld a,%10000000 ; row 8
    ; output row strobe
    out (KEYSCAN_OUT),a            
    ; get column values
    in a,(KEYSCAN_IN)
    and %00010000 ; row 8, bit 5 is RIGHT SHIFT
    ; left shift modifier
    jr nz,_modifier_r_shift
    ; no modifiers
    ld a,0
    ret
_modifier_l_shift:
    ld a,MOD_KEY_SHIFT_L
    ret
_modifier_r_shift:
    ld a,MOD_KEY_SHIFT_R
    ret

; A contains row bitmap representing new keystrokes,  
; DE contains a pointer to the ASCII map for the row - which is incremented in the subroutine
; first printable character returned in A
_colscan:
    ; preserve registers
    push bc
    ; initialise col bit mask - only 1 bit is ever set at a time - it is shifted from bit 0 to bit 7
    ld c,$01
    ; stash the bitmap
    ld b,a                    
_colscanloop:
    ; reload the bitmap
    ld a,b
    ; mask the bitmap - use the column mask (C) over the bitmap value in A
    and c
    ; if zero then no keypress
    jr z,_colscanloopnext
    ld a,(de)
    ; ASCII is 0?
    cp 0
    jr nz,_colscanend
_colscanloopnext:
    ; increment character map pointer
    inc de
    ; clear the carry flag
    or a                        
    ; shift row bit left - when we've done all 8, it will move to the carry flag
    rl c                        
    ; loop if not done all rows
    jr nc,_colscanloop          
_colscanend:
    ; restore registers 
    pop bc
    ret

; define values for control keys
; modifiers have zero value
QWERTY_SHIFT_L equ 0
QWERTY_SHIFT_R equ 0
QWERTY_FN equ 0
QWERTY_CTRL equ 0
QWERTY_ALT equ 0
QWERTY_CMD equ 0
QWERTY_CURS_UP equ 1
QWERTY_CURS_DOWN equ 2
QWERTY_CURS_LEFT equ 3
QWERTY_CURS_RIGHT equ 4
QWERTY_CAPS equ 5
QWERTY_UNDEFINED equ 12

QWERTY_KEYMAP_L:
    db ESC_E,'1','2','3','4','5','6','7'
    db '8','9','0','-','=',ESC_B,QWERTY_CURS_UP,QWERTY_CURS_DOWN
    db ESC_T,'q','w','e','r','t','y','u'
    db 'i','o','p','[',']',ESC_N,QWERTY_CURS_LEFT,QWERTY_CURS_RIGHT
    db QWERTY_CAPS,'a','s','d','f','g','h','j'
    db 'k','l',';',QUOTE,SLASH,QWERTY_FN,QWERTY_CTRL,QWERTY_ALT
    db QWERTY_SHIFT_L,'`','z','x','c','v','b','n'
    db 'm',',','.','/',QWERTY_SHIFT_R,QWERTY_CMD,' ',QWERTY_UNDEFINED
QWERTY_KEYMAP_U:
    db ESC_E,'!','@','#','$','%','^','&'
    db '*','(',')','_','+',ESC_B,QWERTY_CURS_UP,QWERTY_CURS_DOWN
    db ESC_T,'Q','W','E','R','T','Y','U'
    db 'I','O','P','{','}',ESC_N,QWERTY_CURS_LEFT,QWERTY_CURS_RIGHT
    db QWERTY_CAPS,'A','S','D','F','G','H','J'
    db 'K','L',':','"','|',QWERTY_FN,QWERTY_CTRL,QWERTY_ALT
    db QWERTY_SHIFT_L,'~','Z','X','C','V','B','N'
    db 'M','<','>','?',QWERTY_SHIFT_R,QWERTY_CMD,' ',QWERTY_UNDEFINED