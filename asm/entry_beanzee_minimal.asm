; entry_beanzee_minimal.asm - Minimal Marvin Entry Point (BeanZee target)
;
; Minimal boot + jump table for Marvin without BBC BASIC.
; Boots directly to the monitor prompt.
;
    EXTERN STACK

    EXTERN marvin_coldstart
    EXTERN marvin_warmstart
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN con_readchar
    EXTERN con_puts
    EXTERN con_putchar_hex
    EXTERN hex_byte_val

    PUBLIC START

    ORG MARVINORG
    ld sp, STACK
    jp _boot

; jump table at fixed addresses - must match jumptable.inc
ALIGN 0x0010
    jp marvin_coldstart  ; 0x0010 - cold start (enter monitor)
    jp marvin_warmstart  ; 0x0013 - warm start (monitor prompt)
    jp con_putchar      ; 0x0016 - write character (A = char)
    jp con_getchar      ; 0x0019 - wait for character (returns A)
    jp con_readchar     ; 0x001C - non-blocking read (returns A, 0 = none)
    jp con_puts         ; 0x001F - print string (HL = address, zero-terminated)
    jp con_putchar_hex  ; 0x0022 - print A as two hex digits
    jp hex_byte_val     ; 0x0025 - parse hex pair from (HL), advance HL
    jp _stub            ; 0x0028 - lcd_init (not available on beanzee)
    jp _stub            ; 0x002B - lcd_putchar (not available on beanzee)
    jp _stub            ; 0x002E - key_readchar (not available on beanzee)
_stub:
    ret
;
; START stub - no BBC BASIC in minimal build
START:
    jp marvin_warmstart
;
;
; ---- Boot Selection ----
;
; BeanZee (USB only): boot to Marvin monitor
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    jp marvin_coldstart
