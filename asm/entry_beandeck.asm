; entry_beandeck.asm - Entry Point (BeanDeck target, combined firmware)
;
; CPU reset vector, jump table, and boot function for the
; combined Marvin + BBC BASIC firmware.
;
; BeanDeck: USB console output, keyboard or USB input.
;   Reset → keyboard input
;   Shift-Reset → USB input
;
; Provides:
;   - CPU boot at 0x0000 (SP init)
;   - Marvin jump table at 0x0010
;   - Boot selection (init console, then start monitor)
;
    EXTERN marvin_coldstart      ; monitor.asm - cold start
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN putchar              ; console - write character
    EXTERN getchar              ; console - blocking read
    EXTERN readchar             ; console - non-blocking read
    EXTERN puts                 ; console - print string
    EXTERN putchar_hex          ; hex.asm - print hex byte
    EXTERN hex_byte_val         ; hex.asm - parse hex pair
    EXTERN key_readchar         ; keymatrix.asm - keyboard read
    EXTERN beanboard_console_init ; beanboard_init.asm - console selection
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
    jp _stub            ; 0x0028 - lcd_init (not yet available on beandeck)
    jp _stub            ; 0x002B - lcd_putchar (not yet available on beandeck)
    jp key_readchar     ; 0x002E - read keyboard
_stub:
    ret
;
;
; ---- Boot Selection ----
;
; BeanDeck: select console input source, then boot to monitor.
;   Shift held at reset → USB console input
;   No key → keyboard input
;
_boot:
    call beanboard_console_init
    jp marvin_coldstart
;
