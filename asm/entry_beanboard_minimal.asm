; entry_beanboard_minimal.asm - Minimal Marvin Entry Point (BeanBoard target)
;
; Minimal boot + jump table for Marvin without BBC BASIC.
; Initialises LCD and console, then boots to the monitor prompt.
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
    EXTERN lcd_init
    EXTERN lcd_putchar
    EXTERN key_readchar
    EXTERN console_select
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_putchar       ; ra8875.asm - write character to display
    EXTERN usb_putchar          ; um245r.asm - USB write character
    EXTERN usb_puts             ; um245r.asm - USB print string
    EXTERN usb_readchar         ; um245r.asm - USB non-blocking read
    EXTERN key_modifiers        ; keymatrix.asm - read modifier keys
    EXTERN lcd_puts             ; hd44780.asm - LCD print string
    EXTERN ra8875_puts          ; ra8875.asm - RA8875 print string
    EXTERN ra8875_console_putchar ; console.asm - RA8875 console write character
    EXTERN ra8875_console_init  ; console.asm - RA8875 console state init
    EXTERN ra8875_console_cursor_x ; console.asm - set cursor column
    EXTERN ra8875_console_cursor_y ; console.asm - set cursor row
    EXTERN ra8875_console_set_cursor_colour ; console.asm - set cursor colour
    EXTERN ra8875_console_set_background_colour ; console.asm - set background colour

    PUBLIC START

    ORG MARVINORG
    ld sp, STACK
    jp _boot

; RST vectors and jump table at fixed addresses - must match jumptable.inc
ALIGN 0x0008
    jp 0x0000     ; RST 08H
ALIGN 0x0010
    jp 0x0000     ; RST 10H
ALIGN 0x0018
    jp 0x0000     ; RST 18H
ALIGN 0x0020
    jp 0x0000     ; RST 20H
ALIGN 0x0028
    jp 0x0000     ; RST 28H
ALIGN 0x0030
    jp 0x0000     ; RST 30H
ALIGN 0x0038
    jp 0x0000     ; RST 38H / IM 1 vector
; MARVIN_COLDSTART EQU 0x0000 (hardware reset, not a table entry)
ALIGN 0x0040
    jp marvin_warmstart  ; 0x0040 - warm start (monitor prompt)
    jp con_putchar       ; 0x0043 - write character (A = char)
    jp con_putchar_hex   ; 0x0046 - print A as two hex digits
    jp con_puts          ; 0x0049 - print string (HL = address, zero-terminated)
    jp con_getchar       ; 0x004C - wait for character (returns A)
    jp con_readchar      ; 0x004F - non-blocking read (returns A, 0 = none)
    jp usb_putchar       ; 0x0052 - USB write character (A = char)
    jp usb_puts          ; 0x0055 - USB print string (HL = address, zero-terminated)
    jp usb_readchar      ; 0x0058 - USB non-blocking read (returns A, 0 = none)
    jp lcd_init          ; 0x005B - initialise LCD
    jp lcd_putchar       ; 0x005E - write character to LCD
    jp lcd_puts          ; 0x0061 - LCD print string (HL = address, zero-terminated)
    jp key_readchar      ; 0x0064 - read keyboard
    jp key_modifiers     ; 0x0067 - read modifier keys
    jp ra8875_initialise ; 0x006A - ra8875 init
    jp ra8875_putchar    ; 0x006D - ra8875 putchar
    jp ra8875_puts       ; 0x0070 - ra8875 print string
    jp ra8875_console_init          ; 0x0073 - ra8875 console state init
    jp ra8875_console_putchar        ; 0x0076 - ra8875 console write character
    jp ra8875_console_cursor_x      ; 0x0079 - set cursor column (A = col)
    jp ra8875_console_cursor_y      ; 0x007C - set cursor row (A = row, logical)
    jp ra8875_console_set_cursor_colour ; 0x007F - set cursor colour (RA8875_COL_* in A)
    jp hex_byte_val                 ; 0x0082 - parse hex pair from (HL), advance HL
    jp ra8875_console_set_background_colour ; 0x0085 - set console background colour (A = colour)
;
; START stub - no BBC BASIC in minimal build
START:
    jp marvin_warmstart
;
;
; ---- Boot Selection ----
;
; BeanBoard: init LCD and select console, then boot to monitor.
;   Shift held at reset → USB console
;   No key → beanboard console: LCD + keyboard
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    call lcd_init
    call console_select
    jp marvin_coldstart
