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
SP   = 0x7FFF
PC   = 0x0014
```

## What's special about the AVR setup

- **Curated registers, not all 32.** A small custom module (`AvrRegs`) shows
  only the registers a given program uses, plus a **decoded SREG** (`I T H S V
  N Z C`, uppercase = set), the **SP**, and the **PC as a byte address**
  (matching the disassembly — the AVR hardware PC is a *word* address, so they
  would otherwise disagree by 2×). `SP` and `PC` show in **every** example's
  dashboard; the working-register set is chosen **per example** by dropping an
  `avr_dashboard.py` next to the program's `main.S` (see below). `SP` is handy
  for catching an uninitialized stack (reads `0x0000`/a low address) versus a
  healthy one near `RAMEND` that dips by 2 on each `rcall`/interrupt.
- **Peripheral pane (per example).** A second module (`AvrPeripheral`) shows
  selected memory-mapped peripheral registers — the headless equivalent of
  Insight's peripheral view. An example lists them in its `avr_dashboard.py`
  (`AVR_PERIPHERALS`); the pane is added to the layout **only** when an example
  defines them (e.g. `asm_blink_pwm` shows TCA0's CTRLA/CTRLB/CNT/PER/CMP2). One
  byte registers can be bit-decoded via `AVR_BITFIELDS`.
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
| `avr_modules.py`   | `~/.gdbinit.d/` | the `AvrRegs` module (curated regs + SREG + PC) |
| `avr_layout.gdb`   | `~/.gdbinit.d/` | layout `source assembly avrregs`; shorter source; hide the `?` column |
| `avr_connect.gdb`  | `~/.gdbinit.d/` | the `connect` command (attach + `break *0` + `load`, then a clean redisplay) |
| `avr_commands.gdb` | `~/.gdbinit.d/` | convenience commands: `cll` (rebuild + reload + list), `mrc` (reset + run) |
| `avr_autostart.py` | `~/.gdbinit.d/` | auto-runs `connect` on startup **if** the cwd has a `main.elf` |
| `avr_settings.gdb` | `~/.gdbinit.d/` | `set confirm off`, `set listsize 0`, global `~/.gdb_history` |
| `gdbearlyinit`     | `~/.gdbearlyinit` | `set startup-quietly on` — suppresses the gdb version banner |

Auto-connect is **global, not per-directory**: `avr_autostart.py` checks for a
`main.elf` in the directory you launched gdb from and, if present, runs
`connect`. Launch `avr-gdb` in any example directory and it attaches + flashes;
plain `gdb` anywhere else is untouched. No per-example `.gdbinit` files.

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
   cp docs/dashboard/avr_modules.py   ~/.gdbinit.d/
   cp docs/dashboard/avr_layout.gdb   ~/.gdbinit.d/
   cp docs/dashboard/avr_connect.gdb  ~/.gdbinit.d/
   cp docs/dashboard/avr_commands.gdb ~/.gdbinit.d/
   cp docs/dashboard/avr_autostart.py ~/.gdbinit.d/
   cp docs/dashboard/avr_settings.gdb ~/.gdbinit.d/
   cp docs/dashboard/gdbearlyinit     ~/.gdbearlyinit
   ```

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
- `cll` — rebuild (`make`), reload onto the target, and list source.
- `mrc` — reset to the vector and run (`mon reset` + `continue`).
- `mon reset` — reset the core to the vector.
- `dashboard -layout source assembly avrregs` — change which panes show.
- `dashboard avrregs` — toggle a pane.

## Adapting to another program

1. Drop an **`avr_dashboard.py`** next to the program's `main.S` choosing the
   registers to show — it's read automatically when you launch `avr-gdb` in that
   directory, and is tracked in the repo per example. For example
   (`AVR64DD_examples/asm_blink/avr_dashboard.py`):
   ```python
   AVR_REG_SET   = ["r18", "r19", "r20"]   # in display order
   AVR_REG_PAIRS = []                       # e.g. [("r30", "r31", "Z")] for Z
   REGS_PER_ROW  = 4
   ```
   With no `avr_dashboard.py`, the defaults in `~/.gdbinit.d/avr_modules.py` apply.

   To also show **peripheral registers**, add `AVR_PERIPHERALS` (and optionally
   `AVR_BITFIELDS`) — the peripheral pane then appears automatically. For
   example (`AVR64DD_examples/asm_blink_pwm/avr_dashboard.py`, TCA0 PWM):
   ```python
   #                name           addr     width
   AVR_PERIPHERALS = [
       ("TCA0.CTRLA",  0x0A00,  1),
       ("TCA0.CTRLB",  0x0A01,  1),
       ("TCA0.CNT",    0x0A20,  2),   # live counter
       ("TCA0.PER",    0x0A26,  2),   # period -> frequency
       ("TCA0.CMP2",   0x0A2C,  2),   # compare -> duty on WO2
   ]
   AVR_BITFIELDS = {                  # per-bit decode for 1-byte regs
       "TCA0.CTRLA": [(0, "ENABLE")],
       "TCA0.CTRLB": [(6, "CMP2EN"), (5, "CMP1EN"), (4, "CMP0EN")],
   }
   ```
   Addresses come from `/usr/avr/include/avr/ioavr64dd32.h` (the `_SFR_MEM*`
   macros) or the datasheet register map — verify them per peripheral.
2. In the program's `main.S`, give each routine `.type ...,@function` and
   `.size ...` so the Assembly pane centers and shows names.

Nothing else: auto-connect is global, so `avr-gdb` in any directory that has a
`main.elf` attaches automatically.

> **Note:** gdb-dashboard and gdb's built-in **TUI** are mutually exclusive —
> enabling TUI (`tui enable` / `layout`) fights the dashboard for the screen and
> requires manual `refresh`. Stay in the dashboard for headless use.
