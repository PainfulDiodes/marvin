IFNDEF _JUMPTABLE_INC
DEFINE _JUMPTABLE_INC

; Marvin jump table - fixed ROM addresses
; Each entry is a 3-byte JP instruction
; Consumers call these addresses for Marvin I/O services
;
; Sections with limited availability note the supported targets in parentheses.
; Unsupported targets have a stub entry that returns immediately.
;
; Jumps are implemented in entry_<target>.asm / entry_<target>_minimal.asm

; ENTRY POINTS - JP to these - they will not RETurn

MARVIN_WARMSTART            EQU 0x0040  ; return to monitor prompt

; FUNCTIONS - CALL  these - they will RETurn

; Console I/O (routes to active console: USB, LCD+kbd, or RA8875+kbd)
MARVIN_PUTCHAR              EQU 0x0043  ; in: A=char           write char
MARVIN_PUTCHAR_HEX          EQU 0x0046  ; in: A=byte           write A as two hex digits
MARVIN_PUTS                 EQU 0x0049  ; in: HL=str(0-term)   write string
MARVIN_GETCHAR              EQU 0x004C  ; out: A=char          blocking read
MARVIN_READCHAR             EQU 0x004F  ; out: A=char (0=none) non-blocking read

; USB I/O  (all targets)
MARVIN_USB_PUTCHAR          EQU 0x0052  ; in: A=char           write char to USB
MARVIN_USB_PUTS             EQU 0x0055  ; in: HL=str(0-term)   write string to USB
MARVIN_USB_READCHAR         EQU 0x0058  ; out: A=char (0=none) non-blocking USB read

; LCD  (beanboard)
MARVIN_LCD_INIT             EQU 0x005B  ;                      initialise LCD
MARVIN_LCD_PUTCHAR          EQU 0x005E  ; in: A=char           write char to LCD
MARVIN_LCD_PUTS             EQU 0x0061  ; in: HL=str(0-term)   write string to LCD

; Keyboard  (beanboard, beandeck)
MARVIN_KEY_READCHAR         EQU 0x0064  ; out: A=char (0=none) non-blocking keyboard read
MARVIN_KEY_MODIFIERS        EQU 0x0067  ; out: A=modifier bits read modifier key state

; RA8875 TFT display  (beandeck)
MARVIN_RA8875_INIT          EQU 0x006A  ; out: Z=ok NZ=fail    initialise RA8875
MARVIN_RA8875_PUTCHAR       EQU 0x006D  ; in: A=char           write char to RA8875
MARVIN_RA8875_PUTS          EQU 0x0070  ; in: HL=str(0-term)   write string to RA8875
MARVIN_RA8875_CONSOLE_INIT             EQU 0x0073 ;            initialise console state
MARVIN_RA8875_CONSOLE_PUTCHAR          EQU 0x0076 ; in: A=char  console write (handles LF, scroll)
MARVIN_RA8875_CONSOLE_CURSOR_X         EQU 0x0079 ; in: A=col  set cursor column (0..RA8875_COLS-1)
MARVIN_RA8875_CONSOLE_CURSOR_Y         EQU 0x007C ; in: A=row  set cursor row (0..RA8875_ROWS-1, logical)
MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR EQU 0x007F ; in: A=colour  set cursor colour (RA8875_COL_*)
MARVIN_RA8875_CONSOLE_SET_BG_COLOUR    EQU 0x0082 ; in: A=colour  set console background colour
MARVIN_RA8875_CONSOLE_CURSOR_HIDE      EQU 0x0085 ; hide software cursor
MARVIN_RA8875_CONSOLE_CURSOR_SHOW      EQU 0x0088 ; show software cursor

ENDIF
