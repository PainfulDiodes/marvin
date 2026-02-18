; boot_beanzee.asm - Boot Code (BeanZee target, combined firmware)
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
    EXTERN putchar              ; console - write character
    EXTERN getchar              ; console - blocking read
    EXTERN readchar             ; console - non-blocking read
    EXTERN puts                 ; console - print string
    EXTERN putchar_hex          ; hex.asm - print hex byte
    EXTERN hex_byte_val         ; hex.asm - parse hex pair
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
;
    INCLUDE "asm/system.inc"
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
;
;
; ---- Boot Selection ----
;
; BeanZee (USB only): always boot to BBC BASIC
;
_boot:
    jp START
;
