; ENTRY.asm - BBC BASIC Platform Functions (BeanBoard target)
;
; Platform-specific functions required by BBC BASIC.
; Boot code and jump table are in asm/boot_beanboard.asm.
;
; Provides:
;   - Platform functions (CLRSCN, PUTCSR, GETCSR, PUTIME, GETIME)
;
    PUBLIC CLRSCN
    PUBLIC PUTCSR
    PUBLIC GETCSR
    PUBLIC PUTIME
    PUBLIC GETIME
;
    EXTERN OSWRCH               ; BMOS.asm - character output
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
