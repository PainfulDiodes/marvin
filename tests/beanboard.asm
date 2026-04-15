; beanboard.asm - Marvin ABI test for beanboard target
;
; Tests all 25 ABI trampoline entries on beanboard hardware.
; All navigation and status output uses USB (MARVIN_USB_*).
; Load output/beanboard/beanboard.ihx into RAM via Marvin ':' command, execute with 'x'.
;
; beanboard has LCD and matrix keyboard but no RA8875 - those entries are stubs.
; Active console (PUTCHAR/PUTS/GETCHAR/READCHAR) routes to LCD+keyboard by default,
; or USB if booted with Shift held.

    INCLUDE "../abi/marvin.inc"
    ORG ORGDEF

    jp start
    INCLUDE "helpers.inc"

; ============================================================
; Test program entry
; ============================================================

start:
    ld hl, msg_header
    call MARVIN_USB_PUTS

; ============================================================
; [1/25] MARVIN_USB_PUTS
; ============================================================
_t01:
    ld hl, msg_t01
    call MARVIN_USB_PUTS           ; this IS the test
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [2/25] MARVIN_USB_PUTCHAR
; ============================================================
_t02:
    ld hl, msg_t02
    call MARVIN_USB_PUTS
    ld a, 'U'
    call MARVIN_USB_PUTCHAR
    ld a, '\n'
    call MARVIN_USB_PUTCHAR
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [3/25] MARVIN_USB_READCHAR (non-blocking)
; ============================================================
_t03:
    ld hl, msg_t03
    call MARVIN_USB_PUTS
_t03_drain:
    call MARVIN_USB_READCHAR       ; drain any stale input
    or a
    jr nz, _t03_drain
    call MARVIN_USB_READCHAR       ; read once with empty buffer - expect 0x00
    push af
    ld hl, msg_result
    call MARVIN_USB_PUTS
    pop af
    call _usb_puthex
    ld hl, msg_expect_00
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [4/25] MARVIN_PUTS (active console)
; ============================================================
_t04:
    ld hl, msg_t04
    call MARVIN_USB_PUTS
    ld hl, msg_con_test
    call MARVIN_PUTS               ; routes to LCD or USB depending on boot mode
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [5/25] MARVIN_PUTCHAR (active console)
; ============================================================
_t05:
    ld hl, msg_t05
    call MARVIN_USB_PUTS
    ld a, 'P'
    call MARVIN_PUTCHAR            ; routes to active console
    ld a, '\n'
    call MARVIN_PUTCHAR
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [6/25] MARVIN_PUTCHAR_HEX (active console)
; ============================================================
_t06:
    ld hl, msg_t06
    call MARVIN_USB_PUTS
    ld a, 0xBE
    call MARVIN_PUTCHAR_HEX        ; prints "BE" to active console
    ld a, '\n'
    call MARVIN_PUTCHAR
    ld hl, msg_expect_be
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [7/25] MARVIN_GETCHAR (blocking, active console)
; ============================================================
_t07:
    ld hl, msg_t07
    call MARVIN_USB_PUTS
    call MARVIN_GETCHAR            ; blocks until active console input
    push af
    ld hl, msg_received
    call MARVIN_USB_PUTS
    pop af
    call _usb_puthex
    ld a, '\n'
    call MARVIN_USB_PUTCHAR
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [8/25] MARVIN_READCHAR (non-blocking, active console)
; ============================================================
_t08:
    ld hl, msg_t08
    call MARVIN_USB_PUTS
    call MARVIN_READCHAR
    push af
    ld hl, msg_result
    call MARVIN_USB_PUTS
    pop af
    call _usb_puthex
    ld hl, msg_expect_00_nc
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [9/25] MARVIN_KEY_READCHAR (matrix keyboard, beanboard)
; ============================================================
_t09:
    ld hl, msg_t09
    call MARVIN_USB_PUTS
    call _usb_waitkey              ; user holds matrix key and presses USB key
    call MARVIN_KEY_READCHAR       ; read immediately while key may still be held
    push af
    ld hl, msg_result
    call MARVIN_USB_PUTS
    pop af
    call _usb_puthex
    ld hl, msg_t09_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [10/25] MARVIN_KEY_MODIFIERS (matrix keyboard, beanboard)
; ============================================================
_t10:
    ld hl, msg_t10
    call MARVIN_USB_PUTS
    call _usb_waitkey              ; user holds Shift and presses USB key
    call MARVIN_KEY_MODIFIERS      ; read immediately while Shift may still be held
    push af
    ld hl, msg_result
    call MARVIN_USB_PUTS
    pop af
    call _usb_puthex
    ld hl, msg_t10_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [11/25] MARVIN_LCD_INIT (beanboard)
; ============================================================
_t11:
    ld hl, msg_t11
    call MARVIN_USB_PUTS
    call MARVIN_LCD_INIT           ; initialises LCD hardware
    ld hl, msg_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [12/25] MARVIN_LCD_PUTCHAR (beanboard)
; ============================================================
_t12:
    ld hl, msg_t12
    call MARVIN_USB_PUTS
    ld a, 'L'
    call MARVIN_LCD_PUTCHAR        ; 'L' should appear on LCD
    ld hl, msg_t12_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [13/25] MARVIN_LCD_PUTS (beanboard)
; ============================================================
_t13:
    ld hl, msg_t13
    call MARVIN_USB_PUTS
    ld hl, msg_lcd_payload
    call MARVIN_LCD_PUTS           ; string should appear on LCD
    ld hl, msg_t13_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [14/25] MARVIN_RA8875_INIT (stub on beanboard)
; ============================================================
_t14:
    ld hl, msg_t14
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_INIT
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [15/25] MARVIN_RA8875_PUTCHAR (stub on beanboard)
; ============================================================
_t15:
    ld hl, msg_t15
    call MARVIN_USB_PUTS
    ld a, 'R'
    call MARVIN_RA8875_PUTCHAR
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [16/25] MARVIN_RA8875_PUTS (stub on beanboard)
; ============================================================
_t16:
    ld hl, msg_t16
    call MARVIN_USB_PUTS
    ld hl, msg_stub_payload
    call MARVIN_RA8875_PUTS
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [17/25] MARVIN_RA8875_CONSOLE_INIT (stub on beanboard)
; ============================================================
_t17:
    ld hl, msg_t17
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_CONSOLE_INIT
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [18/25] MARVIN_RA8875_CONSOLE_PUTCHAR (stub on beanboard)
; ============================================================
_t18:
    ld hl, msg_t18
    call MARVIN_USB_PUTS
    ld a, 'C'
    call MARVIN_RA8875_CONSOLE_PUTCHAR
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [19/25] MARVIN_RA8875_CONSOLE_CURSOR_HIDE (stub on beanboard)
; ============================================================
_t19:
    ld hl, msg_t19
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_CONSOLE_CURSOR_HIDE
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [20/25] MARVIN_RA8875_CONSOLE_CURSOR_SHOW (stub on beanboard)
; ============================================================
_t20:
    ld hl, msg_t20
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_CONSOLE_CURSOR_SHOW
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [21/25] MARVIN_RA8875_CONSOLE_CURSOR_X (stub on beanboard)
; ============================================================
_t21:
    ld hl, msg_t21
    call MARVIN_USB_PUTS
    ld a, 5
    call MARVIN_RA8875_CONSOLE_CURSOR_X
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [22/25] MARVIN_RA8875_CONSOLE_CURSOR_Y (stub on beanboard)
; ============================================================
_t22:
    ld hl, msg_t22
    call MARVIN_USB_PUTS
    ld a, 2
    call MARVIN_RA8875_CONSOLE_CURSOR_Y
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [23/25] MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR (stub on beanboard)
; ============================================================
_t23:
    ld hl, msg_t23
    call MARVIN_USB_PUTS
    ld a, 0x04
    call MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [24/25] MARVIN_RA8875_CONSOLE_SET_BG_COLOUR (stub on beanboard)
; ============================================================
_t24:
    ld hl, msg_t24
    call MARVIN_USB_PUTS
    ld a, 0x00
    call MARVIN_RA8875_CONSOLE_SET_BG_COLOUR
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [25/25] MARVIN_WARMSTART
; ============================================================
_t25:
    ld hl, msg_t25
    call MARVIN_USB_PUTS
    call _usb_waitkey
    jp MARVIN_WARMSTART

; ============================================================
; String data
; ============================================================

msg_header:
    db "\n=== MARVIN ABI TEST: BEANBOARD ===\n"
    db "25 trampoline entries | USB navigation throughout.\n"
    db "LCD and keyboard entries are real on beanboard.\n"
    db "RA8875 entries are stubs on beanboard.\n\n", 0

msg_anykey:
    db "  [press any USB key]\n", 0

msg_result:
    db "  Result: ", 0

msg_received:
    db "  Received: ", 0

msg_returned:
    db "  Returned.\n", 0

msg_expect_00:
    db " (expect 00 - buffer empty)\n", 0

msg_expect_00_nc:
    db " (expect 00 if no input pending)\n", 0

msg_expect_be:
    db "  Active console should show: BE\n", 0

msg_stub_returned:
    db "  Returned. (stub on beanboard - no action expected)\n", 0

msg_stub_payload:
    db "test string", 0

msg_lcd_payload:
    db "LCD test", 0

msg_con_test:
    db "MARVIN_PUTS: active console\n", 0

msg_t01:
    db "[1/25] MARVIN_USB_PUTS\n"
    db "  If you can read this, MARVIN_USB_PUTS works.\n", 0

msg_t02:
    db "\n[2/25] MARVIN_USB_PUTCHAR\n"
    db "  Sending 'U' via MARVIN_USB_PUTCHAR: ", 0

msg_t03:
    db "\n[3/25] MARVIN_USB_READCHAR (non-blocking)\n"
    db "  Draining buffer, then calling with empty buffer...\n", 0

msg_t04:
    db "\n[4/25] MARVIN_PUTS (active console)\n"
    db "  Default console on beanboard is LCD.\n"
    db "  String should appear on LCD (or USB if Shift-boot)...\n", 0

msg_t05:
    db "\n[5/25] MARVIN_PUTCHAR (active console)\n"
    db "  Sending 'P' to active console: ", 0

msg_t06:
    db "\n[6/25] MARVIN_PUTCHAR_HEX (active console)\n"
    db "  Sending 0xBE to active console as hex: ", 0

msg_t07:
    db "\n[7/25] MARVIN_GETCHAR (blocking, active console)\n"
    db "  Default console on beanboard is LCD+keyboard.\n"
    db "  Press a key on the matrix keyboard (or USB if Shift-boot)...\n", 0

msg_t08:
    db "\n[8/25] MARVIN_READCHAR (non-blocking, active console)\n"
    db "  Calling with no input pending...\n", 0

msg_t09:
    db "\n[9/25] MARVIN_KEY_READCHAR (matrix keyboard)\n"
    db "  Hold a matrix key, then press any USB key...\n", 0

msg_t09_note:
    db " (00 = no key held at read time)\n", 0

msg_t10:
    db "\n[10/25] MARVIN_KEY_MODIFIERS\n"
    db "  Hold Shift on matrix keyboard, then press any USB key...\n", 0

msg_t10_note:
    db " (01 = Shift held)\n", 0

msg_t11:
    db "\n[11/25] MARVIN_LCD_INIT\n"
    db "  Calling LCD initialise...\n", 0

msg_t12:
    db "\n[12/25] MARVIN_LCD_PUTCHAR\n"
    db "  Sending 'L' to LCD...\n", 0

msg_t12_note:
    db "  LCD should show: L\n", 0

msg_t13:
    db "\n[13/25] MARVIN_LCD_PUTS\n"
    db "  Sending string to LCD...\n", 0

msg_t13_note:
    db "  LCD should show: LCD test\n", 0

msg_t14:
    db "\n[14/25] MARVIN_RA8875_INIT\n"
    db "  Stub on beanboard - calling...\n", 0

msg_t15:
    db "\n[15/25] MARVIN_RA8875_PUTCHAR\n"
    db "  Stub on beanboard - calling with 'R'...\n", 0

msg_t16:
    db "\n[16/25] MARVIN_RA8875_PUTS\n"
    db "  Stub on beanboard - calling with string...\n", 0

msg_t17:
    db "\n[17/25] MARVIN_RA8875_CONSOLE_INIT\n"
    db "  Stub on beanboard - calling...\n", 0

msg_t18:
    db "\n[18/25] MARVIN_RA8875_CONSOLE_PUTCHAR\n"
    db "  Stub on beanboard - calling with 'C'...\n", 0

msg_t19:
    db "\n[19/25] MARVIN_RA8875_CONSOLE_CURSOR_HIDE\n"
    db "  Stub on beanboard - calling...\n", 0

msg_t20:
    db "\n[20/25] MARVIN_RA8875_CONSOLE_CURSOR_SHOW\n"
    db "  Stub on beanboard - calling...\n", 0

msg_t21:
    db "\n[21/25] MARVIN_RA8875_CONSOLE_CURSOR_X\n"
    db "  Stub on beanboard - calling with col=5...\n", 0

msg_t22:
    db "\n[22/25] MARVIN_RA8875_CONSOLE_CURSOR_Y\n"
    db "  Stub on beanboard - calling with row=2...\n", 0

msg_t23:
    db "\n[23/25] MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR\n"
    db "  Stub on beanboard - calling with colour=04...\n", 0

msg_t24:
    db "\n[24/25] MARVIN_RA8875_CONSOLE_SET_BG_COLOUR\n"
    db "  Stub on beanboard - calling with colour=00...\n", 0

msg_t25:
    db "\n[25/25] MARVIN_WARMSTART\n"
    db "  All tests done. Press any USB key to return to monitor...\n", 0
