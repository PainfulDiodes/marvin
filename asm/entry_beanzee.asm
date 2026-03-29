; entry_beanzee.asm - Entry Point (BeanZee target, combined firmware)
;
; CPU reset vector, jump table, and boot function for the
; combined Marvin + BBC BASIC firmware.
;
; Provides:
;   - CPU boot at 0x0000 (SP init)
;   - Marvin jump table at 0x0010
;   - Boot selection (BeanZee: always BASIC)
;
    EXTERN marvin_coldstart      ; monitor.asm - cold start
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN con_putchar          ; console - write character
    EXTERN con_getchar          ; console - blocking read
    EXTERN con_readchar         ; console - non-blocking read
    EXTERN con_puts             ; console - print string
    EXTERN con_putchar_hex      ; hex.asm - print hex byte
    EXTERN hex_byte_val         ; hex.asm - parse hex pair
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
;
    EXTERN STACK
;
;
; ---- Boot Code ----
;
    ORG 0x0000
    ld sp, STACK
    jp _boot
;
;
; ---- Jump Table ----
;
; Fixed ROM addresses - must match jumptable.inc
;
ALIGN 0x0010
    jp marvin_coldstart  ; 0x0010 - cold start (enter monitor)
    jp marvin_warmstart  ; 0x0013 - warm start (monitor prompt)
    jp con_putchar      ; 0x0016 - write character (A = char)
    jp con_getchar      ; 0x0019 - wait for character (returns A)
    jp con_readchar     ; 0x001C - non-blocking read (returns A, 0 = none)
    jp con_puts         ; 0x001F - print string (HL = address, zero-terminated)
    jp con_putchar_hex  ; 0x0022 - print A as two hex digits
    jp hex_byte_val     ; 0x0025 - parse hex pair from (HL), advance HL
    jp _stub            ; 0x0028 - key_readchar (not available on beanzee)
    jp _stub            ; 0x002B - lcd_init (not available on beanzee)
    jp _stub            ; 0x002E - lcd_putchar (not available on beanzee)
    jp _stub            ; 0x0031 - ra8875_init (not available on beanzee)
    jp _stub            ; 0x0034 - ra8875_putchar (not available on beanzee)
_stub:
    ret
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
;
