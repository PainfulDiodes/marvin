IFNDEF _JUMPTABLE_INC
DEFINE _JUMPTABLE_INC

; Marvin jump table - fixed ROM addresses
; Each entry is a 3-byte JP instruction
; Consumers call these addresses for Marvin I/O services
;
; Must match the jump table in entry_<target>.asm / entry_<target>_minimal.asm
;
; Availability column: beanzee / beanboard / beandeck
;   real = function connected    stub = entry exists but returns immediately

MARVIN_COLDSTART            EQU 0x0000  ; jp here to cold start (hardware reset)

; Monitor
MARVIN_WARMSTART            EQU 0x0040  ; return to monitor prompt

; Console I/O (routes to active console: USB, LCD+kbd, or RA8875+kbd)
MARVIN_PUTCHAR              EQU 0x0043  ; in: A=char           write char
MARVIN_PUTCHAR_HEX          EQU 0x0046  ; in: A=byte           write A as two hex digits
MARVIN_PUTS                 EQU 0x0049  ; in: HL=str(0-term)   write string
MARVIN_GETCHAR              EQU 0x004C  ; out: A=char          blocking read
MARVIN_READCHAR             EQU 0x004F  ; out: A=char (0=none) non-blocking read

; USB I/O  (real / real / real)
MARVIN_USB_PUTCHAR          EQU 0x0052  ; in: A=char           write char to USB
MARVIN_USB_PUTS             EQU 0x0055  ; in: HL=str(0-term)   write string to USB
MARVIN_USB_READCHAR         EQU 0x0058  ; out: A=char (0=none) non-blocking USB read

; LCD  (stub / real / stub)
MARVIN_LCD_INIT             EQU 0x005B  ;                      initialise LCD
MARVIN_LCD_PUTCHAR          EQU 0x005E  ; in: A=char           write char to LCD
MARVIN_LCD_PUTS             EQU 0x0061  ; in: HL=str(0-term)   write string to LCD

; Keyboard  (stub / real / real)
MARVIN_KEY_READCHAR         EQU 0x0064  ; out: A=char (0=none) non-blocking keyboard read
MARVIN_KEY_MODIFIERS        EQU 0x0067  ; out: A=modifier bits read modifier key state

; RA8875 TFT display  (stub / real / real)
MARVIN_RA8875_INIT          EQU 0x006A  ; out: Z=ok NZ=fail    initialise RA8875
MARVIN_RA8875_PUTCHAR       EQU 0x006D  ; in: A=char           write char to RA8875
MARVIN_RA8875_PUTS          EQU 0x0070  ; in: HL=str(0-term)   write string to RA8875
MARVIN_RA8875_CONSOLE_PUTCHAR EQU 0x0073 ; in: A=char          console write (handles LF, scroll)

; Utility
MARVIN_HEX_BYTE_VAL         EQU 0x0076  ; in: HL=hex pair  out: A=value, HL advanced by 2

ENDIF
