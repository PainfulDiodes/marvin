; beandeck.asm - Marvin ABI test for beandeck target
;
; Tests all 25 ABI trampoline entries on beandeck hardware.
; All navigation and status output uses USB (MARVIN_USB_*).
; Load output/beandeck/beandeck.ihx into RAM via Marvin ':' command, execute with 'x'.
;
; beandeck has matrix keyboard and RA8875 TFT display but no LCD - LCD entries are stubs.
; Active console (PUTCHAR/PUTS/GETCHAR/READCHAR) routes to RA8875+keyboard by default,
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
    call MARVIN_PUTS               ; routes to RA8875 or USB depending on boot mode
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
; [9/25] MARVIN_KEY_READCHAR (matrix keyboard, beandeck)
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
; [10/25] MARVIN_KEY_MODIFIERS (matrix keyboard, beandeck)
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
; [11/25] MARVIN_LCD_INIT (stub on beandeck)
; ============================================================
_t11:
    ld hl, msg_t11
    call MARVIN_USB_PUTS
    call MARVIN_LCD_INIT
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [12/25] MARVIN_LCD_PUTCHAR (stub on beandeck)
; ============================================================
_t12:
    ld hl, msg_t12
    call MARVIN_USB_PUTS
    ld a, 'L'
    call MARVIN_LCD_PUTCHAR
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [13/25] MARVIN_LCD_PUTS (stub on beandeck)
; ============================================================
_t13:
    ld hl, msg_t13
    call MARVIN_USB_PUTS
    ld hl, msg_stub_payload
    call MARVIN_LCD_PUTS
    ld hl, msg_stub_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [14/25] MARVIN_RA8875_INIT (beandeck)
; ============================================================
_t14:
    ld hl, msg_t14
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_INIT
    jr z, _t14_ok
    ld hl, msg_ra8875_fail
    call MARVIN_USB_PUTS
    jr _t14_done
_t14_ok:
    ld hl, msg_ra8875_ok
    call MARVIN_USB_PUTS
_t14_done:
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [15/25] MARVIN_RA8875_PUTCHAR (beandeck)
; ============================================================
_t15:
    ld hl, msg_t15
    call MARVIN_USB_PUTS
    ld a, 'R'
    call MARVIN_RA8875_PUTCHAR     ; 'R' should appear on TFT
    ld hl, msg_t15_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [16/25] MARVIN_RA8875_PUTS (beandeck)
; ============================================================
_t16:
    ld hl, msg_t16
    call MARVIN_USB_PUTS
    ld hl, msg_ra8875_payload
    call MARVIN_RA8875_PUTS        ; string should appear on TFT
    ld hl, msg_t16_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [17/25] MARVIN_RA8875_CONSOLE_INIT (beandeck)
; ============================================================
_t17:
    ld hl, msg_t17
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_CONSOLE_INIT ; resets console state, cursor to 0,0
    ld hl, msg_returned
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [18/25] MARVIN_RA8875_CONSOLE_PUTCHAR (beandeck)
; ============================================================
_t18:
    ld hl, msg_t18
    call MARVIN_USB_PUTS
    ld a, 'C'
    call MARVIN_RA8875_CONSOLE_PUTCHAR ; 'C' should appear on TFT console
    ld hl, msg_t18_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [19/25] MARVIN_RA8875_CONSOLE_CURSOR_HIDE (beandeck)
; ============================================================
_t19:
    ld hl, msg_t19
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_CONSOLE_CURSOR_HIDE
    ld hl, msg_t19_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [20/25] MARVIN_RA8875_CONSOLE_CURSOR_SHOW (beandeck)
; ============================================================
_t20:
    ld hl, msg_t20
    call MARVIN_USB_PUTS
    call MARVIN_RA8875_CONSOLE_CURSOR_SHOW
    ld hl, msg_t20_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [21/25] MARVIN_RA8875_CONSOLE_CURSOR_X (beandeck)
; ============================================================
_t21:
    ld hl, msg_t21
    call MARVIN_USB_PUTS
    ld a, 5
    call MARVIN_RA8875_CONSOLE_CURSOR_X ; cursor should move to column 5
    ld hl, msg_t21_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [22/25] MARVIN_RA8875_CONSOLE_CURSOR_Y (beandeck)
; ============================================================
_t22:
    ld hl, msg_t22
    call MARVIN_USB_PUTS
    ld a, 2
    call MARVIN_RA8875_CONSOLE_CURSOR_Y ; cursor should move to row 2
    ld hl, msg_t22_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [23/25] MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR (beandeck)
; ============================================================
_t23:
    ld hl, msg_t23
    call MARVIN_USB_PUTS
    ld a, 0x04                     ; RA8875_COL_YELLOW
    call MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR
    ld hl, msg_t23_note
    call MARVIN_USB_PUTS
    ld hl, msg_anykey
    call MARVIN_USB_PUTS
    call _usb_waitkey

; ============================================================
; [24/25] MARVIN_RA8875_CONSOLE_SET_BG_COLOUR (beandeck)
; ============================================================
_t24:
    ld hl, msg_t24
    call MARVIN_USB_PUTS
    ld a, 0x00                     ; RA8875_COL_BLACK
    call MARVIN_RA8875_CONSOLE_SET_BG_COLOUR
    ld hl, msg_t24_note
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
    db "\n=== MARVIN ABI TEST: BEANDECK ===\n"
    db "25 trampoline entries | USB navigation throughout.\n"
    db "Keyboard and RA8875 entries are real on beandeck.\n"
    db "LCD entries are stubs on beandeck.\n\n", 0

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
    db "  Returned. (stub on beandeck - no action expected)\n", 0

msg_stub_payload:
    db "test string", 0

msg_ra8875_payload:
    db "RA8875 test", 0

msg_con_test:
    db "MARVIN_PUTS: active console\n", 0

msg_ra8875_ok:
    db "  OK - Z flag set.\n", 0

msg_ra8875_fail:
    db "  FAIL - NZ flag (check SPI hardware).\n", 0

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
    db "  Default console on beandeck is RA8875 TFT.\n"
    db "  String should appear on TFT (or USB if Shift-boot)...\n", 0

msg_t05:
    db "\n[5/25] MARVIN_PUTCHAR (active console)\n"
    db "  Sending 'P' to active console: ", 0

msg_t06:
    db "\n[6/25] MARVIN_PUTCHAR_HEX (active console)\n"
    db "  Sending 0xBE to active console as hex: ", 0

msg_t07:
    db "\n[7/25] MARVIN_GETCHAR (blocking, active console)\n"
    db "  Default console on beandeck is RA8875+keyboard.\n"
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
    db "  Stub on beandeck - calling...\n", 0

msg_t12:
    db "\n[12/25] MARVIN_LCD_PUTCHAR\n"
    db "  Stub on beandeck - calling with 'L'...\n", 0

msg_t13:
    db "\n[13/25] MARVIN_LCD_PUTS\n"
    db "  Stub on beandeck - calling with string...\n", 0

msg_t14:
    db "\n[14/25] MARVIN_RA8875_INIT\n"
    db "  Calling RA8875 initialise...\n", 0

msg_t15:
    db "\n[15/25] MARVIN_RA8875_PUTCHAR\n"
    db "  Sending 'R' to RA8875...\n", 0

msg_t15_note:
    db "  TFT should show: R\n", 0

msg_t16:
    db "\n[16/25] MARVIN_RA8875_PUTS\n"
    db "  Sending string to RA8875...\n", 0

msg_t16_note:
    db "  TFT should show: RA8875 test\n", 0

msg_t17:
    db "\n[17/25] MARVIN_RA8875_CONSOLE_INIT\n"
    db "  Calling console init (resets state, cursor to 0,0)...\n", 0

msg_t18:
    db "\n[18/25] MARVIN_RA8875_CONSOLE_PUTCHAR\n"
    db "  Sending 'C' to RA8875 console...\n", 0

msg_t18_note:
    db "  TFT console should show: C\n", 0

msg_t19:
    db "\n[19/25] MARVIN_RA8875_CONSOLE_CURSOR_HIDE\n"
    db "  Hiding cursor...\n", 0

msg_t19_note:
    db "  TFT cursor should be hidden.\n", 0

msg_t20:
    db "\n[20/25] MARVIN_RA8875_CONSOLE_CURSOR_SHOW\n"
    db "  Showing cursor...\n", 0

msg_t20_note:
    db "  TFT cursor should be visible.\n", 0

msg_t21:
    db "\n[21/25] MARVIN_RA8875_CONSOLE_CURSOR_X\n"
    db "  Setting cursor column to 5...\n", 0

msg_t21_note:
    db "  TFT cursor should move to column 5.\n", 0

msg_t22:
    db "\n[22/25] MARVIN_RA8875_CONSOLE_CURSOR_Y\n"
    db "  Setting cursor row to 2...\n", 0

msg_t22_note:
    db "  TFT cursor should move to row 2.\n", 0

msg_t23:
    db "\n[23/25] MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR\n"
    db "  Setting cursor colour to yellow (04)...\n", 0

msg_t23_note:
    db "  TFT cursor should be yellow.\n", 0

msg_t24:
    db "\n[24/25] MARVIN_RA8875_CONSOLE_SET_BG_COLOUR\n"
    db "  Setting background colour to black (00)...\n", 0

msg_t24_note:
    db "  TFT background should be black.\n", 0

msg_t25:
    db "\n[25/25] MARVIN_WARMSTART\n"
    db "  All tests done. Press any USB key to return to monitor...\n", 0
