; entry_beandeck.asm - Minimal Marvin Entry Point (BeanDeck target)
;
; Minimal boot + jump table for Marvin without BBC BASIC.
; USB console output, keyboard or USB input.
;   Reset → keyboard input
;   Shift-Reset → USB input
;
    INCLUDE "asm/system.inc"

    EXTERN marvin_coldstart
    EXTERN marvin_warmstart
    EXTERN putchar
    EXTERN getchar
    EXTERN readchar
    EXTERN puts
    EXTERN putchar_hex
    EXTERN hex_byte_val
    EXTERN key_readchar
    EXTERN beanboard_console_init

    PUBLIC START

    ORG MARVINORG
    ld sp, STACK
    call beanboard_console_init

; jump table at fixed addresses - must match jumptable.inc
ALIGN 0x0010
    jp marvin_coldstart  ; 0x0010 - cold start (enter monitor)
    jp marvin_warmstart  ; 0x0013 - warm start (monitor prompt)
    jp putchar          ; 0x0016 - write character (A = char)
    jp getchar          ; 0x0019 - wait for character (returns A)
    jp readchar         ; 0x001C - non-blocking read (returns A, 0 = none)
    jp puts             ; 0x001F - print string (HL = address, zero-terminated)
    jp putchar_hex      ; 0x0022 - print A as two hex digits
    jp hex_byte_val     ; 0x0025 - parse hex pair from (HL), advance HL
    jp _stub            ; 0x0028 - lcd_init (not yet available on beandeck)
    jp _stub            ; 0x002B - lcd_putchar (not yet available on beandeck)
    jp key_readchar     ; 0x002E - read keyboard
_stub:
    ret
;
; START stub - no BBC BASIC in minimal build
START:
    jp marvin_warmstart
