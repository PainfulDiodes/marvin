# Marvin

Firmware for the BeanZee Z80 homebrew family. The build includes Marvin, a simple [monitor program](./monitor.md) and also RT Russell's [BBCZ80](https://github.com/PainfulDiodes/BBCZ80) BASIC interpreter. BBCZ80 calls Marvin's hardware drivers via a jump table at fixed ROM addresses.

## Hardware Targets

- **beanzee** - console over USB serial only (UM245R)
- **beanboard** - BeanZee + LCD display + keyboard + GPIO
- **beandeck** - BeanBoard + TFT display / flash cartridge storage via BeanBoardSPI

## Building

Requires [z88dk](https://github.com/z88dk/z88dk) (z88dk-z80asm).

Clone repo with submodules:

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

Build standalone monitor (no BASIC interpreter):

```bash
./targets/beanzee/build-standalone.sh
./targets/beanboard/build-standalone.sh
```

Output binaries are placed in `targets/<target>/output/`.

## Memory Map

- 0x0000 - 0x7FFF : 32k ROM (firmware)
- 0x8000 - 0xEFFF : User program area
- 0xF000 - 0xFFFF : System RAM (monitor use + stack)

Stack starts at 0xFFFF (working down).

## Jump Table

Fixed ROM addresses at 0x0010 for platform-independent access:

| Address | Function                              |
|---------|---------------------------------------|
| 0x0010  | Cold start (enter monitor)            |
| 0x0013  | Warm start (monitor prompt)           |
| 0x0016  | putchar (A = char)                    |
| 0x0019  | getchar (blocking, returns A)         |
| 0x001C  | readchar (non-blocking, returns A)    |
| 0x001F  | puts (HL = string address)            |
| 0x0022  | putchar_hex (A as two hex digits)     |
| 0x0025  | hex_byte_val (parse hex pair from HL) |
| 0x0028  | lcd_init                              |
| 0x002B  | lcd_putchar                           |
| 0x002E  | key_readchar                          |

## Monitor Commands

See: [monitor](./monitor.md)

## BBC BASIC

BBC BASIC Z80 interpreter included as a git submodule - [beanzee-bbc-basic](https://github.com/PainfulDiodes/beanzee-bbc-basic). Monitor commands:

- `*MON` - Drop into monitor
- `BYE` - Return to monitor

## Links

- [BBCZ80](https://github.com/PainfulDiodes/BBCZ80)
- [BeanZee board](https://github.com/PainfulDiodes/BeanZee)
- [BeanZeeBytes example programs](https://github.com/PainfulDiodes/BeanZeeBytes)
- [Blog](https://painfuldiodes.wordpress.com)
