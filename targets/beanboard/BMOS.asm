; BMOS.asm - BeanZeeOS Machine Operating System (BeanBoard target)
;
; OS interface for BBC BASIC Z80 on BeanBoard hardware.
; Delegates I/O to Marvin via the jump table. BeanBoard adds
; LCD display and matrix keyboard routed through Marvin's
; console abstraction.
;
; Marvin's console layer handles routing between USB serial and
; LCD/keyboard based on CONSOLE_STATUS. BMOS always calls the
; same jump table entries regardless of active console.
;
; Line ending handling:
;   USB console: Marvin translates CR→LF in, LF→CR+LF out.
;     BMOS compensates: LF→CR on input, swallow CR on output.
;   Beanboard console: no USB translation applies.
;     LF→CR conversion is harmless if keyboard returns CR directly.
;     Swallowing CR on output: Marvin's LCD driver uses LF for newline.
;
; cf. bbcbasic/targets/beanzee/BMOS.asm (standalone version)
;
    PUBLIC OSINIT
    PUBLIC OSRDCH
    PUBLIC OSWRCH
    PUBLIC OSKEY
    PUBLIC OSLINE
    PUBLIC PROMPT
    PUBLIC OSSAVE
    PUBLIC OSLOAD
    PUBLIC OSOPEN
    PUBLIC OSSHUT
    PUBLIC OSBGET
    PUBLIC OSBPUT
    PUBLIC OSSTAT
    PUBLIC GETEXT
    PUBLIC GETPTR
    PUBLIC PUTPTR
    PUBLIC RESET
    PUBLIC BYE
    PUBLIC TRAP
    PUBLIC LTRAP
    PUBLIC OSCLI
    PUBLIC OSCALL
;
    EXTERN ESCAPE       ; MAIN.Z80 - escape handler
    EXTERN EXTERR       ; MAIN.Z80 - external error
    EXTERN CRLF         ; MAIN.Z80 - output CR+LF
    EXTERN VERMSG       ; MAIN.Z80 - version message
;
    EXTERN ACCS         ; DATA.Z80 - string accumulator
    EXTERN USER         ; DATA.Z80 - end of data segment (PAGE)
;
    INCLUDE "asm/jumptable.inc"
;
; Character constants
;
CR          EQU 0DH
LF          EQU 0AH
ESC         EQU 1BH
BS          EQU 08H
DEL         EQU 7FH
;
;
; ---- OS Initialisation ----
;
;OSINIT - Initialise hardware and return memory layout.
;   Outputs: DE = initial value of HIMEM (top of RAM)
;            HL = initial value of PAGE (user program)
;   Destroys: A,B,C,D,E,H,L,F
;
OSINIT:
    XOR A
    LD B,INILEN
    LD HL,_FLAGS
CLRTAB:
    LD (HL),A           ; Clear local state
    INC HL
    DJNZ CLRTAB
    LD HL,ACCS
    LD (HL),CR          ; No auto-run file
    LD DE,0F000H        ; HIMEM - reserve 0xF000-0xFFFF for Marvin + stack
    LD HL,USER          ; PAGE  - start of user program area
    RET
;
;
; ---- Console Output ----
;
;OSWRCH - Write a character to console output.
;   Inputs: A = character.
;   Destroys: Nothing
;
OSWRCH:
    PUSH AF
    CP CR
    JR Z,_OSWRCH_DONE   ; Swallow CR (Marvin adds CR before LF)
    CALL MARVIN_PUTCHAR
_OSWRCH_DONE:
    POP AF
    RET
;
;PROMPT - Output the command prompt.
;   Destroys: A,F
;
PROMPT:
    LD A,'>'
    JP OSWRCH
;
;
; ---- Console Input ----
;
;OSRDCH - Read from the current input stream (keyboard).
;   Outputs: A = character
;   Destroys: A,F
;
OSRDCH:
    LD A,(_INKEY)       ; Check for buffered key
    OR A
    JR Z,_OSRDCH_CALL
    PUSH HL
    LD HL,_INKEY
    LD (HL),0           ; Clear buffer
    POP HL
    RET
_OSRDCH_CALL:
    CALL MARVIN_GETCHAR ; Blocking read
    CP LF               ; Marvin returns LF for Enter (USB console)
    RET NZ
    LD A,CR             ; Convert to CR for BASIC
    RET
;
;OSKEY - Read key with time-limit, test for ESCape.
;   Inputs: HL = time limit (centiseconds)
;   Outputs: Carry reset if time-out.
;            If carry set, A = character.
;   Destroys: A,H,L,F
;
OSKEY:
    LD A,(_INKEY)       ; Check buffered key
    PUSH HL
    LD HL,_INKEY
    LD (HL),0
    POP HL
    OR A
    SCF
    RET NZ              ; Return buffered key
    PUSH DE
_OSKEY_LOOP:
    CALL MARVIN_READCHAR ; Non-blocking read
    OR A
    JR NZ,_OSKEY_GOT
    DEC HL              ; Decrement timeout
    LD A,H
    OR L
    JR NZ,_OSKEY_LOOP
    POP DE
    OR A                ; Clear carry = timeout
    RET
_OSKEY_GOT:
    POP DE
    CP LF               ; Marvin returns LF for Enter (USB console)
    JR NZ,_OSKEY_NOTLF
    LD A,CR             ; Convert to CR for BASIC
_OSKEY_NOTLF:
    CP ESC
    SCF
    RET NZ              ; Non-ESC key, carry set
    PUSH HL             ; ESC pressed
    LD HL,_FLAGS
    BIT 6,(HL)          ; Escape disabled?
    JR NZ,_OSKEY_ESCDIS
    SET 7,(HL)          ; Set escape flag
_OSKEY_ESCDIS:
    POP HL
    RET
;
;OSLINE - Read a complete line, terminated by CR.
;   Inputs: HL addresses destination buffer.
;           (L=0)
;   Outputs: Buffer filled, terminated by CR.
;            A=0.
;   Destroys: A,B,C,D,E,H,L,F
;
OSLINE:
_OSLINE_LOOP:
    CALL OSRDCH
    CP CR
    JR Z,_OSLINE_DONE
    CP BS
    JR Z,_OSLINE_BS
    CP DEL
    JR Z,_OSLINE_BS
    CP ESC
    JR Z,_OSLINE_ESC
    CP ' '
    JR C,_OSLINE_LOOP   ; Ignore control characters
    LD B,A              ; Save character
    LD A,L
    CP 254              ; Buffer full?
    LD A,B              ; Restore character
    JR NC,_OSLINE_LOOP  ; Full, ignore
    LD (HL),A           ; Store character
    INC L
    CALL OSWRCH         ; Echo
    JR _OSLINE_LOOP
;
_OSLINE_BS:
    LD A,L
    OR A
    JR Z,_OSLINE_LOOP   ; At start, nothing to delete
    DEC L
    LD A,BS
    CALL OSWRCH
    LD A,' '
    CALL OSWRCH
    LD A,BS
    CALL OSWRCH
    JR _OSLINE_LOOP
;
_OSLINE_DONE:
    LD (HL),CR          ; Terminate line
    CALL CRLF
    XOR A               ; A=0
    LD L,A              ; L=0 (point to buffer start)
    RET
;
_OSLINE_ESC:
    LD (HL),CR          ; Terminate line
    CALL CRLF
    LD HL,_FLAGS
    RES 7,(HL)          ; Clear escape flag
    JP ESCAPE           ; Abort
;
;
; ---- Trap Handlers ----
;
;TRAP - Test ESCAPE flag and abort if set;
;       every 20th call, poll keyboard for ESCape.
;   Destroys: A,H,L,F
;
TRAP:
    LD HL,_TRPCNT
    DEC (HL)
    CALL Z,_TEST
LTRAP:
    LD A,(_FLAGS)
    OR A
    RET P               ; Bit 7 clear, no escape
    LD HL,_FLAGS        ; Escape pending
    RES 7,(HL)          ; Acknowledge
    JP ESCAPE           ; Abort
;
;_TEST - Non-blocking keyboard poll for ESCape.
;   Destroys: A,F
;
_TEST:
    LD (HL),20          ; Reset trap counter
    CALL MARVIN_READCHAR ; Non-blocking poll
    OR A
    RET Z               ; No data
    CP LF               ; Marvin returns LF for Enter (USB console)
    JR NZ,_TEST_NOTLF
    LD A,CR             ; Convert to CR for BASIC
_TEST_NOTLF:
    CP ESC
    JR Z,_TEST_ESC
    LD (_INKEY),A       ; Buffer non-ESC key
    RET
_TEST_ESC:
    LD HL,_FLAGS
    BIT 6,(HL)          ; Escape disabled?
    RET NZ
    SET 7,(HL)          ; Set escape flag
    RET
;
;
; ---- System Control ----
;
;RESET - Full cold restart.
;
RESET:
    RST 0               ; Jump to address 0x0000
;
;BYE - Return to Marvin monitor.
;
BYE:
    JP MARVIN_WARMSTART ; Enter Marvin prompt
;
;OSCLI - Process an "operating system" command.
;   Inputs: HL addresses command string (after '*')
;
OSCLI:
_OSCLI_SKIP:
    LD A,(HL)
    CP ' '
    JR NZ,_OSCLI_CHECK
    INC HL
    JR _OSCLI_SKIP
_OSCLI_CHECK:
    CP CR
    RET Z               ; Empty command
    CP '|'
    RET Z               ; Comment
    ; Check for *MON / *MONITOR
    AND 0DFH            ; Force uppercase
    CP 'M'
    JR NZ,_OSCLI_BAD
    INC HL
    LD A,(HL)
    AND 0DFH
    CP 'O'
    JR NZ,_OSCLI_BAD
    INC HL
    LD A,(HL)
    AND 0DFH
    CP 'N'
    JR NZ,_OSCLI_BAD
    JP MARVIN_WARMSTART ; *MON matched - enter monitor
;
_OSCLI_BAD:
    LD A,254
    CALL EXTERR
    DEFM "Bad command"
    DEFB 0
;
;OSCALL - Call OS function (not used).
;
OSCALL:
    RET
;
;
; ---- File Operations (stubs) ----
;
;OSSAVE - Save an area of memory to a file.
;   Inputs: HL addresses filename (term CR)
;           DE = start address of data to save
;           BC = length of data to save (bytes)
;   Destroys: A,B,C,D,E,H,L,F
;
OSSAVE:
OSLOAD:
    XOR A
    CALL EXTERR
    DEFM "Sorry"
    DEFB 0
;
;OSOPEN - Open a file for reading or writing.
;   Inputs: HL addresses filename (term CR)
;           Carry set for OPENIN, cleared for OPENOUT.
;   Outputs: A = file channel (0 = cannot open)
;   Destroys: A,B,C,D,E,H,L,F
;
OSOPEN:
    XOR A               ; A=0, cannot open
    RET
;
;OSSHUT - Close disk file(s).
;   Inputs: E = file channel
;           If E=0 all files are closed.
;   Destroys: A,B,C,D,E,H,L,F
;
OSSHUT:
    RET
;
;OSBGET - Read a byte from a random disk file.
;   Inputs: E = file channel
;   Outputs: A = byte read
;            Carry set if last byte of file.
;   Destroys: A,B,C,F
;
OSBGET:
    XOR A               ; A=0
    SCF                 ; Carry set = EOF
    RET
;
;OSBPUT - Write a byte to a random disk file.
;   Inputs: E = file channel
;           A = byte to write
;   Destroys: A,B,C,F
;
OSBPUT:
    RET
;
;OSSTAT - Read file status.
;   Inputs: E = file channel
;   Outputs: Z flag set = EOF
;   Destroys: A,D,E,H,L,F
;
OSSTAT:
    XOR A               ; Z set = EOF
    RET
;
;GETPTR - Return file pointer.
;   Inputs: E = file channel
;   Outputs: DEHL = pointer (0-&7FFFFF)
;   Destroys: A,B,C,D,E,H,L,F
;
GETPTR:
    LD DE,0
    LD HL,0
    RET
;
;PUTPTR - Update file pointer.
;   Inputs: A = file channel
;           DEHL = new pointer
;   Destroys: A,B,C,D,E,H,L,F
;
PUTPTR:
    RET
;
;GETEXT - Find file size.
;   Inputs: E = file channel
;   Outputs: DEHL = file size
;   Destroys: A,B,C,D,E,H,L,F
;
GETEXT:
    LD DE,0
    LD HL,0
    RET
;
;
; ---- Local State ----
;
; Flags byte:
;   Bit 6: Escape disabled
;   Bit 7: Escape flag (pending escape)
;
_TRPCNT:
    DEFB 20
_FLAGS:
    DEFB 0
_INKEY:
    DEFB 0
INILEN  EQU $-_FLAGS
;
FIN:
