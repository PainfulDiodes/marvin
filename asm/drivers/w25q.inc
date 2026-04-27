; w25q.inc - W25Q series NOR flash constants for BeanBoardSPI hardware SPI
;
; CS values are for the 74HCT373 active-low SPI control register (SPI_CTRL port).
; Port addresses (SPI_CTRL, SPI_DATA) are in system.asm.

; Active-low CS values: bit (slot+1) low, all other bits high
W25Q_CS_SLOT1   EQU 0xFB    ; slot 1: bit 2 low
W25Q_CS_SLOT2   EQU 0xF7    ; slot 2: bit 3 low
W25Q_CS_SLOT3   EQU 0xEF    ; slot 3: bit 4 low
W25Q_CS_SLOT4   EQU 0xDF    ; slot 4: bit 5 low
W25Q_CS_SLOT5   EQU 0xBF    ; slot 5: bit 6 low
W25Q_CS_SLOT6   EQU 0x7F    ; slot 6: bit 7 low
W25Q_CS_IDLE    EQU 0xFF    ; all CS deasserted, RESET released

; Command bytes
W25Q_CMD_JEDEC_ID   EQU 0x9F    ; Read JEDEC ID
W25Q_CMD_READ       EQU 0x03    ; Read Data
W25Q_CMD_WREN       EQU 0x06    ; Write Enable
W25Q_CMD_SE         EQU 0x20    ; Sector Erase (4KB)
W25Q_CMD_PP         EQU 0x02    ; Page Program
W25Q_CMD_RDSR       EQU 0x05    ; Read Status Register 1

; Status register bits
W25Q_BUSY_BIT       EQU 0       ; bit 0: BUSY (1 = operation in progress)

; Polling timeout (loop iterations)
; At 10MHz Z80 with ~134 T-states/iteration (~13 µs): 0xFFFF ≈ 0.88s
; Covers W25Q16/W25Q128 worst-case 400ms sector erase.
W25Q_POLL_TIMEOUT   EQU 0xFFFF

; JEDEC manufacturer IDs
W25Q_MFR_WINBOND    EQU 0xEF    ; Winbond NOR flash

; Capacity codes (JEDEC third byte, returned by flash_read_jedec_id and cached in w25q_id_cap)
; Capacity byte = log2(bits); e.g. 0x15 = log2(16Mbit) + constant
W25Q_CAP_8MBIT      EQU 0x14    ; W25Q80   - 1 MByte
W25Q_CAP_16MBIT     EQU 0x15    ; W25Q16   - 2 MByte
W25Q_CAP_32MBIT     EQU 0x16    ; W25Q32   - 4 MByte
W25Q_CAP_64MBIT     EQU 0x17    ; W25Q64   - 8 MByte
W25Q_CAP_128MBIT    EQU 0x18    ; W25Q128  - 16 MByte
W25Q_CAP_256MBIT    EQU 0x19    ; W25Q256  - 32 MByte
