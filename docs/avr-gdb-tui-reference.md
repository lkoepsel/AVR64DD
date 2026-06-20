# avr-gdb TUI Quick Reference (AVR64DD32)

A one-page guide to the text user interface for stepping through AVR assembly.

## Starting / toggling the TUI

| Action | Command / Key |
|---|---|
| Start gdb in TUI mode | `avr-gdb -tui program.elf` |
| Toggle TUI on/off | `Ctrl-x a` |
| Enable from prompt | `tui enable` |
| Redraw a corrupted screen | `Ctrl-L` |

## Layouts

| Command | Shows |
|---|---|
| `layout asm` | Disassembly: Flash address + instruction (PC highlighted) |
| `layout regs` | Register window stacked on the current code window |
| `layout src` | Source code (needs `-g` debug info) |
| `layout split` | Source + disassembly together |
| `layout next` / `layout prev` | Cycle through layouts |

For assembly work the pairing is `layout asm` then `layout regs`.

## Register window

| Command | Effect |
|---|---|
| `tui reg general` | r0-r31, PC, SP, SREG |
| `tui reg all` | Everything, including I/O-mapped |
| `tui reg next` | Cycle to next register group |

Changed registers highlight after each step - this is the main payoff of the
register window when single-stepping.

## Window focus and scrolling

| Key | Action |
|---|---|
| `Ctrl-x o` | Move focus to the next window |
| `Ctrl-x 1` | Single window |
| `Ctrl-x 2` | Two windows |
| `PgUp` / `PgDn` | Scroll the focused window |
| `Ctrl-P` / `Ctrl-N` | Command history (use these when a window has focus and the arrow keys are captured) |

**Common gotcha:** when a code or register window has focus, the arrow keys
scroll it instead of recalling history. Use `Ctrl-x o` to return focus to the
command window, or use `Ctrl-P` / `Ctrl-N` for history.

## Stepping through assembly

| Command | Action |
|---|---|
| `si` (or `stepi`) | Execute one instruction |
| `ni` (or `nexti`) | One instruction, stepping over `call`/`rcall` |
| `c` (or `continue`) | Run to next breakpoint |
| `b *0` | Breakpoint at reset vector (Flash 0x0000) |
| `b *<label>` | Breakpoint at an assembly label |
| `info registers` | Dump all registers (or use the `regs` alias) |
| `x/8i $pc` | Disassemble 8 instructions from PC |
| `x/8xb 0x6000` | Examine 8 SRAM bytes (SRAM starts at 0x6000) |

## AVR address note

The disassembly window shows **byte addresses** for Flash, which line up with
what `display/i $pc` prints. The AVR program counter counts **words**, so if you
cross-reference a word-addressed listing or the datasheet, halve the gdb byte
address to get the word address.

## AVR64DD32 specifics

- Interface: **UPDI** via the Curiosity Nano's on-board **nEDBG** debugger
- Has hardware breakpoints (unlike the ATtiny13A), so `b *<label>` works freely
- SRAM data space starts at **0x6000** (8 KB)
- Flash program memory starts at **0x0000** (reset vector)
