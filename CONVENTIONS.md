# Conventions

## Coding

"Callable" labels - i.e. addresses of functions which will end in a ret code - are in lowercase

Other labels, including jump addresses and data labels are in uppercase

Private labels - those which should not be referenced outside of their file are prefixed with an underscore

## Build / Structural Conventions

Target-specific files (ENTRY.asm, MOS.asm) use uppercase names matching BBC BASIC conventions and live in `targets/<target>/`.

Marvin core modules use lowercase names with underscores and live in `asm/`.

Standalone entry files for Marvin-only builds use `entry_<target>.asm` in `asm/`.

Shared BBC BASIC modules (HOOK.asm, MOS.asm) live in `asm/BBCZ80/`.
