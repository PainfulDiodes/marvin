; beanboard.inc - BeanBoard GPIO pin assignments for SPI use
;
; Shared between ra8875_beanboard.asm and spi_beanboard.asm

; GPIO output pin assignments
GPO_BIT_SCK     equ 0           ; serial clock
GPO_BIT_MOSI    equ 1           ; master out
GPO_BIT_RESET   equ 2           ; RA8875 /RESET (active low)
GPO_BIT_CS      equ 3           ; chip select (active low)

; GPIO input pin assignment
GPI_BIT_MISO    equ 0           ; master in

; CS/RESET control states
GPO_RESET_STATE     equ 1 << GPO_BIT_CS                         ; RESET asserted, CS inactive
GPO_INACTIVE_STATE  equ 1 << GPO_BIT_CS | 1 << GPO_BIT_RESET    ; RESET inactive, CS inactive
GPO_ACTIVE_STATE    equ 1 << GPO_BIT_RESET                      ; RESET inactive, CS asserted

; Data transfer states: CS held low, RESET held high
GPO_LOW_STATE   equ 1 << GPO_BIT_RESET                          ; MOSI=0, SCK=0
GPO_HIGH_STATE  equ 1 << GPO_BIT_MOSI | 1 << GPO_BIT_RESET      ; MOSI=1, SCK=0
