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
    EXTERN con_putchar          ; console - write character
    EXTERN con_getchar          ; console - blocking read
    EXTERN con_readchar         ; console - non-blocking read
    EXTERN con_puts             ; console - print string
    EXTERN con_putchar_hex      ; hex.asm - print hex byte
    EXTERN hex_byte_val         ; hex.asm - parse hex pair
    EXTERN key_readchar         ; keymatrix.asm - keyboard read
    EXTERN console_select       ; console_select.asm - console selection
    EXTERN CONSOLE_STATUS, CONSOLE_STATUS_USB ; system.asm - force USB fallback
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_putchar       ; ra8875.asm - write character to display
    EXTERN ra8875_console_init  ; console.asm (ra8875-z80-repo) - console state init
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
;
    EXTERN STACK
    EXTERN CAPS_LOCK_STATE
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
    jp key_readchar     ; 0x0028 - read keyboard
    jp _stub            ; 0x002B - lcd_init (not available on beandeck)
    jp _stub            ; 0x002E - lcd_putchar (not available on beandeck)
    jp ra8875_initialise ; 0x0031 - ra8875 init
    jp ra8875_putchar   ; 0x0034 - ra8875 putchar
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
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
    call ra8875_initialise
    jr nz,_boot_ra8875_failed   ; init failed: force USB console
    ld bc,0x8000                ; post-init settling delay (~100ms at 10MHz)
_boot_settle:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_settle
    call ra8875_console_init
    call console_select
    jp marvin_coldstart
_boot_ra8875_failed:
    ; RA8875 initialisation failed (no SPI response or memory-clear timeout).
    ; Fall back to USB console so the monitor is at least reachable.
    ;
    ; LIMITATIONS - this is a minimal fallback, not a proper error path:
    ;
    ; 1. Silent failure: there is no way to tell the user what went wrong.
    ;    The display is blank or shows uninitialised VRAM. The only indication
    ;    that something failed is that the monitor appears on USB instead of
    ;    the TFT — easy to miss if USB is not already connected.
    ;
    ; 2. Requires prior knowledge: the user must know to connect USB and open
    ;    a terminal. There is no beep, LED flash, or other out-of-band signal.
    ;
    ; 3. Future consideration: treat USB as STDERR.
    ;    USB output could be kept always-on as an error/diagnostic channel,
    ;    independent of the selected console. A startup failure message (or any
    ;    runtime error) could then be sent to USB regardless of which console
    ;    is active — analogous to stderr vs stdout. This would make failures
    ;    visible without requiring the user to know something went wrong first.
    ;    That would require the console layer to support a separate diagnostic
    ;    output path (e.g. usb_puts at the hardware level, bypassing CONSOLE_STATUS).
    ld a,CONSOLE_STATUS_USB
    ld (CONSOLE_STATUS),a
    jp marvin_coldstart
;
