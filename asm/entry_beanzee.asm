; entry_beanzee.asm - Standalone Marvin Entry Point (BeanZee target)
;
; Minimal boot + jump table for standalone Marvin (no BBC BASIC).
; Boots directly to the monitor prompt.
;
    INCLUDE "asm/system.inc"

    EXTERN MARVIN
    EXTERN monitor_prompt
    EXTERN putchar
    EXTERN getchar
    EXTERN readchar
    EXTERN puts
    EXTERN putchar_hex
    EXTERN hex_byte_val

    ORG MARVINORG
    ld sp, STACK

; jump table at fixed addresses - must match jumptable.inc
ALIGN 0x0010
    jp MARVIN           ; 0x0010 - warm start (enter monitor)
    jp monitor_prompt   ; 0x0013 - monitor prompt
    jp putchar          ; 0x0016 - write character (A = char)
    jp getchar          ; 0x0019 - wait for character (returns A)
    jp readchar         ; 0x001C - non-blocking read (returns A, 0 = none)
    jp puts             ; 0x001F - print string (HL = address, zero-terminated)
    jp putchar_hex      ; 0x0022 - print A as two hex digits
    jp hex_byte_val     ; 0x0025 - parse hex pair from (HL), advance HL
    jp _stub            ; 0x0028 - lcd_init (not available on beanzee)
    jp _stub            ; 0x002B - lcd_putchar (not available on beanzee)
    jp _stub            ; 0x002E - key_readchar (not available on beanzee)
_stub:
    ret
