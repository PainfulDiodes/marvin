    INCLUDE "asm/system.inc"

    PUBLIC console_select

    EXTERN modifierkeys
    EXTERN MOD_KEY_SHIFT

; determine which console should be active - Reset=beanboard, shift-Reset=USB
console_select:
    ; check for modifier keys being held down
    call modifierkeys
    ; shift key down?
    and MOD_KEY_SHIFT
    ; yes shift
    jp nz,_console_select_usb
    ; no shift
    ld a,CONSOLE_STATUS_BEANBOARD
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
_console_select_usb:
    ld a,CONSOLE_STATUS_USB
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
