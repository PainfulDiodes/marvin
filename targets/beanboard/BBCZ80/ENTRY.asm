; ENTRY.asm - BeanZeeOS Entry Point (BeanBoard target)
;
; Combined entry point replacing both Marvin's boot module
; (marvin_beanboard.asm) and BBC BASIC's platform module
; (BEANZEE.asm) for the BeanZeeOS combined firmware.
;
; Provides:
;   - CPU boot at 0x0000 (SP init, LCD init, console selection)
;   - Marvin jump table at 0x0010
;   - Boot selection (shift at reset → Marvin, default → BASIC)
;   - Platform functions (CLRSCN, PUTCSR, GETCSR, PUTIME, GETIME)
;
    PUBLIC CLRSCN
    PUBLIC PUTCSR
    PUBLIC GETCSR
    PUBLIC PUTIME
    PUBLIC GETIME
;
    EXTERN MARVIN               ; monitor.asm - warm start
    EXTERN monitor_prompt       ; monitor.asm - monitor prompt loop
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
    EXTERN OSWRCH               ; BMOS.asm - character output
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
    jp MARVIN           ; 0x0010 - warm start (enter monitor)
    jp monitor_prompt   ; 0x0013 - monitor prompt
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
; BeanBoard: init LCD and determine console, then boot.
;   Shift held at reset → Marvin monitor (USB console)
;   No key → BBC BASIC (beanboard console: LCD + keyboard)
;
_boot:
    call lcd_init
    call beanboard_console_init
    ld a,(CONSOLE_STATUS)
    cp CONSOLE_STATUS_USB
    jp z, MARVIN        ; Shift held → Marvin (USB)
    jp START            ; Default → BASIC (LCD + keyboard)
;
;
; ---- Platform Functions ----
;
;CLRSCN - Clear screen and home cursor.
;   Send VT100 escape sequence: ESC[2J ESC[H
;   Destroys: A,D,E,H,L,F
;
CLRSCN:
    LD A,1BH            ; ESC
    CALL OSWRCH
    LD A,'['
    CALL OSWRCH
    LD A,'2'
    CALL OSWRCH
    LD A,'J'
    CALL OSWRCH
    LD A,1BH            ; ESC
    CALL OSWRCH
    LD A,'['
    CALL OSWRCH
    LD A,'H'
    JP OSWRCH           ; Cursor home and return
;
;PUTCSR - Move cursor to specified position.
;   Inputs: DE = horizontal position (LHS=0)
;           HL = vertical position (TOP=0)
;   Destroys: A,D,E,H,L,F
;
PUTCSR:
    RET                 ; Not implemented
;
;GETCSR - Return cursor coordinates.
;   Outputs: DE = X coordinate (POS)
;            HL = Y coordinate (VPOS)
;   Destroys: A,D,E,H,L,F
;
GETCSR:
    LD DE,0
    LD HL,0
    RET
;
;PUTIME - Load elapsed-time clock.
;   Inputs: DEHL = time to load (centiseconds)
;   Destroys: A,D,E,H,L,F
;
PUTIME:
    RET                 ; No clock hardware
;
;GETIME - Read elapsed-time clock.
;   Outputs: DEHL = elapsed time (centiseconds)
;   Destroys: A,D,E,H,L,F
;
GETIME:
    LD DE,0
    LD HL,0
    RET
;
FIN:
