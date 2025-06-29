DEBOUNCE_DELAY  equ 0x4000

MOD_KEY_SHIFT   equ 0b00000001
MOD_KEY_FN      equ 0b00000010
MOD_KEY_CONTROL equ 0b00000100
MOD_KEY_ALT     equ 0b00001000
MOD_KEY_CMD     equ 0b00010000

; return keyboard char value in A, or 0
key_readchar:
    push bc
    push de
    push hl
    ; initial row bit - only 1 bit is ever set at a time - it is shifted from bit 0 to bit 7
    ld b,0x01                    
    ; row counter - 0 => 7
    ld c,0x00                    
    ; location of previous values
    ld hl,KEY_MATRIX_BUFFER
    call modifierkeys
    ; initialise map pointer
    ld de,QWERTY_KEYMAP_L
    ; shift key down?
    and MOD_KEY_SHIFT
    jp z,_keyscanloop
    ld de,QWERTY_KEYMAP_U
_keyscanloop:
    call _rowscan
    ; ASCII returned in A, or 0
    call _colscan 
    cp 0
    jp nz,key_readchar_end
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
key_readchar_end:
    ; debounce delay, restore state and return
    call _debounce_delay
    pop hl
    pop de
    pop bc
    ret

_debounce_delay:
    push af
    push de
    ld de,DEBOUNCE_DELAY
_delay_loop:
    dec de
    nop
    ld a, d
    cp 0
    jr nz,_delay_loop
_delay_end:
    pop de
    pop af
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

; return bitmap representing modifier keys in A
modifierkeys:                       
    ld a,0b00010000 ; row 4
    ; output row strobe
    out (KEYSCAN_OUT),a            
    ; get column values
    in a,(KEYSCAN_IN)
    and 0b00000001 ; row 4, bit 0 is SHIFT
    ; left shift modifier
    jr nz,_modifier_shift
    ; no modifiers
    ld a,0
    ret
_modifier_shift:
    ld a,MOD_KEY_SHIFT
    ret

; A contains row bitmap representing new keystrokes,  
; DE contains a pointer to the ASCII map for the row - which is incremented in the subroutine
; first printable character returned in A
_colscan:
    ; preserve registers
    push bc
    ; initialise col bit mask - only 1 bit is ever set at a time - it is shifted from bit 0 to bit 7
    ld c,0x01
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
QWERTY_SHIFT equ 0
QWERTY_FN equ 0
QWERTY_CTRL equ 0
QWERTY_ALT equ 0
QWERTY_CMD equ 0
QWERTY_CURS_UP equ 1
QWERTY_CURS_DOWN equ 2
QWERTY_CURS_LEFT equ 3
QWERTY_CURS_RIGHT equ 4
QWERTY_CAPS equ 5

QWERTY_KEYMAP_L:
    db ESC_E,'q','w','e','r','t','y','u','i','o','p',QWERTY_CAPS,ESC_B,'7','8','9'
    db ESC_T,'a','s','d','f','g','h','j','k','l',';',QUOTE,ESC_N,'4','5','6'
    db QWERTY_SHIFT,'z','x','c','v','b','n','m',',','.','/',SLASH,QWERTY_CURS_UP,'1','2','3'
    db QWERTY_FN,QWERTY_CTRL,QWERTY_ALT,QWERTY_CMD,' ','[',']',' ','`','-','=',QWERTY_CURS_LEFT,QWERTY_CURS_DOWN,QWERTY_CURS_RIGHT,'0',ESC_N
QWERTY_KEYMAP_U:
    db ESC_E,'Q','W','E','R','T','Y','U','I','O','P',QWERTY_CAPS,ESC_B,'&','*','('
    db ESC_T,'A','S','D','F','G','H','J','K','L',':','"',ESC_N,'$','%','^'
    db QWERTY_SHIFT,'Z','X','C','V','B','N','M','<','>','?',SLASH,QWERTY_CURS_UP,'!','@','#'
    db QWERTY_FN,QWERTY_CTRL,QWERTY_ALT,QWERTY_CMD,' ','{','}',' ','~','_','+',QWERTY_CURS_LEFT,QWERTY_CURS_DOWN,QWERTY_CURS_RIGHT,')',ESC_N
