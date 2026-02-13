    INCLUDE "asm/system.inc"

    EXTERN MARVIN
    EXTERN PROMPT
    EXTERN putchar
    EXTERN getchar
    EXTERN readchar
    EXTERN puts
    EXTERN putchar_hex
    EXTERN hex_byte_val
    EXTERN lcd_init
    EXTERN lcd_putchar
    EXTERN key_readchar
    EXTERN beanboard_console_init

    ORG MARVINORG
    ld sp, STACK
    call lcd_init
    call beanboard_console_init

; jump table at fixed addresses - must match jumptable.inc
ALIGN 0x0010
    jp MARVIN           ; 0x0010 - warm start (enter monitor)
    jp PROMPT           ; 0x0013 - monitor prompt
    jp putchar          ; 0x0016 - write character (A = char)
    jp getchar          ; 0x0019 - wait for character (returns A)
    jp readchar         ; 0x001C - non-blocking read (returns A, 0 = none)
    jp puts             ; 0x001F - print string (HL = address, zero-terminated)
    jp putchar_hex      ; 0x0022 - print A as two hex digits
    jp hex_byte_val     ; 0x0025 - parse hex pair from (HL), advance HL
    jp lcd_init         ; 0x0028 - initialise LCD
    jp lcd_putchar      ; 0x002B - write character to LCD
    jp key_readchar     ; 0x002E - read keyboard
