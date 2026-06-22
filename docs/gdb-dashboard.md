# Headless Debugging with gdb-dashboard (AVR64DD32 + Bloom)

[Bloom Insight](https://bloom.oscillate.io/) is excellent, but it is a Qt GUI —
it does not work when you SSH into a **headless Raspberry Pi** with the board
plugged in (a common classroom setup). [**gdb-dashboard**](https://github.com/cyrus-and/gdb-dashboard)
is a pure-terminal front-end for `avr-gdb`: source, disassembly, and a curated
register view, all redrawn on every stop, entirely over the terminal/SSH.

This page describes the AVR64DD32 dashboard configuration shipped in
[`docs/dashboard/`](./dashboard). The result, when you launch `avr-gdb` in an
example directory, is a clean three-pane view halted at the reset vector:

```
── Source ──────────────────────────────────────────
   (main.S, current line highlighted)
── Assembly ────────────────────────────────────────
   (disassembly centered on PC, AVR byte addresses)
── AVR Registers ───────────────────────────────────
r18=0x15  r19=0xFA  r20=0x3B
SREG = 0x00  [ i t h s v n z c ]      (UPPER=set, lower=clear)
PC   = 0x0014
```

## What's special about the AVR setup

- **Curated registers, not all 32.** A small custom module (`AvrRegs`) shows
  only the registers a given program uses, plus a **decoded SREG** (`I T H S V
  N Z C`, uppercase = set) and the **PC as a byte address** (matching the
  disassembly — the AVR hardware PC is a *word* address, so they would
  otherwise disagree by 2×). Edit `AVR_REG_SET` at the top of `avr_modules.py`
  per program.
- **SREG name gotcha.** gdb's register is `SREG` (uppercase, case-sensitive);
  `sreg`/`$sreg` silently fail. The module reads `SREG`.
- **Assembly centering needs function symbols.** gdb-dashboard centers the
  disassembly on the PC by disassembling the *current function* — which only
  works if the address is covered by an `STT_FUNC` symbol. Plain asm labels are
  not functions, so the example sources mark their entry points with
  `.type <label>, @function` / `.size <label>, .-<label>` (see
  `AVR64DD_examples/asm_blink/main.S`). This also removes the `?` that
  gdb-dashboard prints for the unknown-function column.
- **Register read/write while halted.** Bloom's `mon rr <peripheral>` /
  `mon wr <peripheral> <reg> <val>` work at the gdb prompt; their output
  appears in the dashboard's *Output/messages* area.

## Files (`docs/dashboard/`)

| File | Install to | Purpose |
|---|---|---|
| `avr_modules.py`  | `~/.gdbinit.d/` | the `AvrRegs` module (curated regs + SREG + PC) |
| `avr_layout.gdb`  | `~/.gdbinit.d/` | layout `source assembly avrregs`; shorter source; hide the `?` column |
| `avr_connect.gdb` | `~/.gdbinit.d/` | the `connect` command (attach + `break *0` + `load`, then a clean redisplay) |
| `avr_settings.gdb`| `~/.gdbinit.d/` | `set confirm off`, `set listsize 0`, and the auto-load safe-path **(edit the path!)** |
| `gdbearlyinit`    | `~/.gdbearlyinit` | `set startup-quietly on` — suppresses the gdb version banner |

Per example, a tiny `.gdbinit` (e.g. `AVR64DD_examples/asm_blink/.gdbinit`)
does `file main.elf` + `connect` so launching `avr-gdb` auto-connects.

## Install

1. **Install gdb-dashboard** as `~/.gdbinit`:
   ```sh
   wget -P ~ https://git.io/.gdbinit      # or copy from the gdb-dashboard repo
   ```
   (Requires a `gdb`/`avr-gdb` built with Python support — the standard
   toolchain has it.)
2. **Copy the AVR files:**
   ```sh
   mkdir -p ~/.gdbinit.d
   cp docs/dashboard/avr_modules.py  ~/.gdbinit.d/
   cp docs/dashboard/avr_layout.gdb  ~/.gdbinit.d/
   cp docs/dashboard/avr_connect.gdb ~/.gdbinit.d/
   cp docs/dashboard/avr_settings.gdb ~/.gdbinit.d/
   cp docs/dashboard/gdbearlyinit    ~/.gdbearlyinit
   ```
3. **Edit the safe-path** in `~/.gdbinit.d/avr_settings.gdb` to your clone's
   absolute path (the `add-auto-load-safe-path` line).

`~/.gdbinit.d/` is auto-sourced by gdb-dashboard: `.py` files load as Python
modules, everything else as GDB scripts.

## Use

Two terminals (or `bloom &`):

```sh
# terminal 1 -- the GDB server
cd AVR64DD_examples/asm_blink && bloom
```
```sh
# terminal 2 -- the debugger (no banner, auto-connects, clean dashboard)
cd AVR64DD_examples/asm_blink && avr-gdb
(gdb) si           # step one instruction; all panes repaint automatically
(gdb) c            # run;  Ctrl-C to halt (or set a breakpoint)
```

- `connect` — re-run the attach/flash/redisplay by hand if needed.
- `mon reset` — reset the core to the vector.
- `dashboard -layout source assembly avrregs` — change which panes show.
- `dashboard avrregs` — toggle a pane.

## Adapting to another program

1. Set `AVR_REG_SET` in `~/.gdbinit.d/avr_modules.py` to the registers that
   program uses.
2. In the program's `main.S`, give each routine `.type ...,@function` and
   `.size ...` so the Assembly pane centers and shows names.
3. Drop a `.gdbinit` (`file main.elf` + `connect`) in that example's directory.

> **Note:** gdb-dashboard and gdb's built-in **TUI** are mutually exclusive —
> enabling TUI (`tui enable` / `layout`) fights the dashboard for the screen and
> requires manual `refresh`. Stay in the dashboard for headless use.
