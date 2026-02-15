# Marvin

Firmware for BeanZee Z80 homebrew hardware. Marvin is a monitor program at the core, with BBC BASIC as the default interpreter. Boots to BASIC; hold Shift at reset to enter the Marvin monitor prompt (BeanBoard/BeanDeck targets).

BASIC calls Marvin's hardware drivers via a jump table at fixed ROM addresses, so there is no driver duplication between the two programs.

## Hardware Targets

- **beanzee** - USB serial only (UM245R). Always boots to BASIC.
- **beanboard** - BeanZee + LCD display + matrix keyboard. Shift at reset selects Marvin (USB console).
- **beandeck** - BeanBoard + BeanBoardSPI (TFT display, flash cartridge storage). Same boot selection as BeanBoard.

## Building

Requires [z88dk](https://github.com/z88dk/z88dk) (z88dk-z80asm).

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/PainfulDiodes/Marvin.git
cd Marvin
```

Build combined firmware (Marvin + BBC BASIC) for all targets:

```bash
./build.sh
```

Build a single target:

```bash
./build.sh beanzee
```

Build standalone Marvin (monitor only, no BBC BASIC):

```bash
./targets/beanzee/build-standalone.sh
./targets/beanboard/build-standalone.sh
```

Output binaries are placed in `targets/<target>/output/`.

## Memory Map

- 0x0000 - 0x7FFF : 32k ROM (firmware)
- 0x8000 - 0xEFFF : User program area
- 0xF000 - 0xFFFF : System RAM (Marvin + stack)

Stack starts at 0xFFFF (working down).

## Jump Table

Fixed ROM addresses at 0x0010 for platform-independent access:

| Address | Function |
|---------|----------|
| 0x0010 | Warm start (enter monitor) |
| 0x0013 | Monitor prompt |
| 0x0016 | putchar (A = char) |
| 0x0019 | getchar (blocking, returns A) |
| 0x001C | readchar (non-blocking, returns A) |
| 0x001F | puts (HL = string address) |
| 0x0022 | putchar_hex (A as two hex digits) |
| 0x0025 | hex_byte_val (parse hex pair from HL) |
| 0x0028 | lcd_init |
| 0x002B | lcd_putchar |
| 0x002E | key_readchar |

## Monitor Commands

- `r [addr]` - Read 16 bytes from memory
- `w addr data...` - Write hex bytes to memory
- `x [addr]` - Execute from address (default: 0x8000)
- `:` - Load Intel HEX record

## BBC BASIC

BBC BASIC Z80 interpreter included as a git submodule ([beanzee-bbc-basic](https://github.com/PainfulDiodes/beanzee-bbc-basic)). Star commands:

- `*MON` - Drop to Marvin monitor
- `BYE` - Return to Marvin

## Links

- [BeanZee board](https://github.com/PainfulDiodes/BeanZee)
- [BeanZeeBytes example programs](https://github.com/PainfulDiodes/BeanZeeBytes)
- [beanzee-bbc-basic](https://github.com/PainfulDiodes/beanzee-bbc-basic)
- [Blog](https://painfuldiodes.wordpress.com)
