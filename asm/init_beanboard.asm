    INCLUDE "asm/system.inc"

    PUBLIC beanboard_console_init

    EXTERN modifierkeys
    EXTERN MOD_KEY_SHIFT

; determine which console should be active - Reset=beanboard, shift-Reset=USB
beanboard_console_init:
    ; check for modifier keys being held down
    call modifierkeys
    ; shift key down?
    and MOD_KEY_SHIFT
    ; yes shift
    jp nz,_beanboard_console_init_usb
    ; no shift
    ld a,CONSOLE_STATUS_BEANBOARD
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
_beanboard_console_init_usb:
    ld a,CONSOLE_STATUS_USB
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
