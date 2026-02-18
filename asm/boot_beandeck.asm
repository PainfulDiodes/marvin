; boot_beandeck.asm - Boot Code (BeanDeck target, combined firmware)
;
; CPU reset vector, jump table, and boot function for the
; combined Marvin + BBC BASIC firmware.
;
; BeanDeck uses the same boot sequence as BeanBoard.
; SPI/TFT initialisation is not required at boot time.
;
; Provides:
;   - CPU boot at 0x0000 (SP init)
;   - Marvin jump table at 0x0010
;   - Boot selection (shift at reset → Marvin, default → BASIC)
;
    EXTERN marvin_coldstart      ; monitor.asm - cold start
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN putchar              ; console - write character
    EXTERN getchar              ; console - blocking read
    EXTERN readchar             ; console - non-blocking read
    EXTERN puts                 ; console - print string
    EXTERN putchar_hex          ; hex.asm - print hex byte
    EXTERN hex_byte_val         ; hex.asm - parse hex pair
    EXTERN lcd_init             ; hd44780.asm - LCD initialisation
    EXTERN lcd_putchar          ; hd44780.asm - LCD character output
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
    jp lcd_init         ; 0x0028 - initialise LCD
    jp lcd_putchar      ; 0x002B - write character to LCD
    jp key_readchar     ; 0x002E - read keyboard
;
;
; ---- Boot Selection ----
;
; BeanDeck: init LCD and determine console, then boot.
;   Shift held at reset → Marvin monitor (USB console)
;   No key → BBC BASIC (beanboard console: LCD + keyboard)
;
_boot:
    call lcd_init
    call beanboard_console_init
    ld a,(CONSOLE_STATUS)
    cp CONSOLE_STATUS_USB
    jp z, marvin_coldstart ; Shift held → Marvin (USB)
    jp START            ; Default → BASIC (LCD + keyboard)
;
