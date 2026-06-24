# AVR64DD32 Sysclock (TCA0 OVF) Setup

This document is a step-by-step guide for the TCA0-based 1 kHz system tick
used in this example, how its vector table is wired, how to view its
registers live in `gdb-dashboard`, and how to retune the tick rate.

The reference implementation is `Library/sysclock.S`. The vector table and
demo loop live in `main.S` in this directory.

---

## 1. What this peripheral does

| Item            | Value                                                    |
|-----------------|----------------------------------------------------------|
| Peripheral      | `TCA0` in SINGLE / NORMAL mode                           |
| Counter width   | 16-bit (`TCA0.SINGLE.CNT`)                               |
| Period register | `TCA0.SINGLE.PER` (counter resets to 0 on `CNT == PER`)  |
| Interrupt       | `TCA0_OVF_vect` = `__vector_9` (byte 0x24 in vector table)|
| Tick storage    | `r9:r8` (`ticks_hi:ticks_lo`) — reserved globally        |
| ISR scratch     | `r2` (`ISR_temp`) — reserved globally                    |
| Default rate    | 1 kHz (1 ms) at 4 MHz `F_CPU`                            |

`r2`, `r8`, `r9` are reserved by the root `Makefile` via `-ffixed-r8
-ffixed-r9` (and the convention for `r2`). Do not clobber them from C or
from your own assembly. See `CLAUDE.md` for the project-wide rule.

---

## 2. Initialization sequence (`init_sysclock_1k`)

`init_sysclock_1k` performs five steps, in this order:

1. **Zero the tick counter.**
   `eor ticks_lo, ticks_lo` / `eor ticks_hi, ticks_hi`.
2. **Set PER = 249** (16-bit write, low byte first).
   `lo8(249) -> TCA0_SINGLE_PERL`, `hi8(249) -> TCA0_SINGLE_PERH`.
3. **Set WGMODE = NORMAL.**
   Write `(0 << TCA_SINGLE_WGMODE_gp)` to `TCA0_SINGLE_CTRLB`.
4. **Enable the OVF interrupt.**
   Write `TCA_SINGLE_OVF_bm` to `TCA0_SINGLE_INTCTRL`.
5. **Start the timer: CLKSEL = DIV16, ENABLE = 1.**
   Write `(4 << TCA_SINGLE_CLKSEL_gp) | TCA_SINGLE_ENABLE_bm` to
   `TCA0_SINGLE_CTRLA`.

Then `sei` to enable interrupts globally and `ret`.

The ISR (`__vector_9` / `TCA0_OVF_handler`) does the minimum:

```
in     ISR_temp, CPU_SREG          ; save flags
ldi    temp_16,  TCA_SINGLE_OVF_bm
sts    TCA0_SINGLE_INTFLAGS, temp_16   ; W1C the OVF flag
inc    ticks_lo
brne   1f
inc    ticks_hi
1:
out    CPU_SREG, ISR_temp
reti
```

Two AVR-Dx quirks worth calling out:

- **OVF is write-1-to-clear.** Unlike Timer0 on the ATtiny, the flag does not
  auto-clear when the ISR runs; you must write `OVF_bm` back to `INTFLAGS`.
- **`ticks()` does an atomic read.** `cli` / `movw r24, r8` / restore SREG —
  otherwise a 16-bit read can tear across an overflow.

---

## 3. Vector table wiring

This example is pure-asm (no `.c` source), so the Makefile sets
`FREESTANDING=1` and the C runtime's weak vector table is not pulled in.
`main.S` therefore declares its own `.vectors` section:

```
.section .vectors, "ax", @progbits
    jmp     reset_handler       ; 0x000  vector 0  RESET
    jmp     0                   ; 0x004  vector 1  NMI       (bad-interrupt trap)
    ...
    jmp     0                   ; 0x020  vector 8  PORTA_PORT
    jmp     TCA0_OVF_handler    ; 0x024  vector 9  TCA0_OVF  <-- 9*4 = byte 0x24
```

> **Vector slots are 4 bytes (`jmp`) on this part, not 2 bytes (`rjmp`).**
> On any AVR with **more than 8 K words** of flash, each interrupt vector is a
> 2-word `jmp` (4 bytes), so vector N is at byte `N * 4`. The AVR64DD32 has
> 64 KB = 32 K words of flash, so `TCA0_OVF` (vector 9) lives at byte `0x24`.
> Using `rjmp`/`reti` (2-byte) entries is a classic, hard-to-spot bug:
> **reset still works** (PC starts at 0 and runs whatever instruction is there),
> so the program appears to boot fine, but every *interrupt* dispatches to the
> wrong address and the ISR silently never runs. Match the CRT — it uses `jmp`:
> `avr-objdump -d crtavr64dd32.o` shows the `__vectors` entries spaced 4 apart.
>
> **Word vs. byte addresses — don't get tripped up.** Datasheet Table 9-3
> ("Interrupt Vector Mapping") lists `TCA0_OVF` at `0x12`, but that column is
> headed **Program Address (*word*)**. The AVR is a 16-bit-word machine, so the
> datasheet tabulates vectors in *words*, while the toolchain (`avr-objdump`,
> the `.vectors` layout, gdb) uses *byte* addresses. Convert with ×2:
> **word `0x12` = byte `0x24`** — the two are the same location, not a conflict.
> The table also confirms the slot size: its word addresses step by `0x02`
> (= 2 words = 4 bytes) per vector.

`sysclock.S` defines both `__vector_9` and a `TCA0_OVF_handler` alias on the
same address, so the same module works either way:

- **Freestanding asm (this example):** the table's `jmp TCA0_OVF_handler`
  goes to the alias.
- **C-runtime build (any example with a `.c` file):** the linker pulls in the
  CRT's weak vector table; `.global __vector_9` overrides slot 9's weak
  default, and you write no `.vectors` section.

Confirm the vector number against the header before trusting it:

```sh
grep TCA0_OVF_vect /usr/lib/avr/include/avr/ioavr64dd32.h
```

---

## 4. Build, flash, and observe

```sh
make flash         # build main.hex and upload
```

`main.S` loops: print `0xBB`, snapshot ticks, busy-wait `COUNTER` iterations,
snapshot ticks again, print the delta in hex, print `0xEE`. The delta tells
you how many tick interrupts fired during the busy wait. With the default
`COUNTER = 30000` at 4 MHz, expect a delta near `0x65` (101); see
`sysclock_timing.md` for the cycle-by-cycle derivation.

---

## 5. Watching TCA0 in `gdb-dashboard`

The existing `avr_dashboard.py` already lists TCA0's registers in
`AVR_PERIPHERALS`. With Bloom running:

```sh
avr-gdb main.elf
(gdb) target remote :1442
(gdb) break TCA0_OVF_handler
(gdb) continue
```

At each break you see `TCA0.CNT` reset to 0, `TCA0.CTRLA` with `ENABLE` set,
and `r9:r8` increment in the register pane. Step past the ISR to watch
`INTFLAGS.OVF` clear after the W1C `sts`.

To also display `INTFLAGS` and `INTCTRL`, add them to `AVR_PERIPHERALS`:

```python
AVR_PERIPHERALS = [
    ("TCA0.CTRLA",    0x0A00, 1),
    ("TCA0.CTRLB",    0x0A01, 1),
    ("TCA0.CNT",      0x0A20, 2),
    ("TCA0.PER",      0x0A26, 2),
    ("TCA0.CMP2",     0x0A2C, 2),
    ("TCA0.INTCTRL",  0x0A0A, 1),     # OVF interrupt enable
    ("TCA0.INTFLAGS", 0x0A0B, 1),     # OVF flag (W1C)
]

AVR_BITFIELDS = {
    "TCA0.CTRLA":    [(0, "ENABLE")],
    "TCA0.CTRLB":    [(6, "CMP2EN"), (5, "CMP1EN"), (4, "CMP0EN")],
    "TCA0.INTCTRL":  [(0, "OVF")],
    "TCA0.INTFLAGS": [(0, "OVF")],
}
```

---

## 6. Changing the tick rate

The OVF frequency is set by two knobs in `init_sysclock_1k`:

```
f_tick = F_CPU / (prescale * (PER + 1))
```

`PER` is the 16-bit `TCA0.SINGLE.PER` (max 65535). Prescale comes from the
`CLKSEL` field in `TCA0.SINGLE.CTRLA`. The encoding:

| `CLKSEL` value | Prescale |
|----------------|----------|
| 0              | /1       |
| 1              | /2       |
| 2              | /4       |
| 3              | /8       |
| 4              | /16      |
| 5              | /64      |
| 6              | /256     |
| 7              | /1024    |

Worked tick rates at `F_CPU = 4 MHz`:

| Target rate | Prescale | PER  | Exact? | Notes                              |
|-------------|----------|------|--------|------------------------------------|
| 1 kHz       | /16      | 249  | exact  | **Default in `sysclock.S`**        |
| 1 kHz       | /64      | 62   | no     | ~1.008 ms (~0.8% slow)             |
| 1 kHz       | /64      | 63   | no     | ~1.024 ms (~2.4% slow)             |
| 100 Hz      | /256     | 156  | exact  | 4 000 000 / (256 * 157) = 100.0    |
| 10 kHz      | /4       | 99   | exact  | 4 000 000 / (4 * 100) = 10 000     |
| 32 Hz       | /1024    | 122  | no     | useful for slow-blink demos        |

To change the rate, edit two lines in `Library/sysclock.S`:

1. The PER write (replace `249` with your new value):
   ```
   ldi  temp_16, lo8(NEW_PER)
   sts  TCA0_SINGLE_PERL, temp_16
   ldi  temp_16, hi8(NEW_PER)
   sts  TCA0_SINGLE_PERH, temp_16
   ```
2. The CLKSEL field in the CTRLA write (replace `0x4` with the value from
   the table):
   ```
   ldi  temp_16, (CLKSEL_VAL << TCA_SINGLE_CLKSEL_gp) | TCA_SINGLE_ENABLE_bm
   sts  TCA0_SINGLE_CTRLA, temp_16
   ```

Then `make clean && make flash`.

If you also bump `F_CPU` (e.g. switch to 24 MHz via CLKCTRL), re-derive PER
with the formula above — the existing PER will be 6× too slow.

When you change the rate, `r9:r8` still increments once per overflow, so the
unit of `ticks()` changes too. If a downstream routine assumes "ticks =
milliseconds," update it (or pick a PER/prescale that keeps the 1 ms unit).

---

## 7. Verification checklist

| Symptom                                       | Likely cause                                          |
|-----------------------------------------------|-------------------------------------------------------|
| ISR never fires (but config + `SREG` `I` look right) | 2-byte `rjmp` vector slots — this part needs 4-byte `jmp` (vector N at `N*4`) |
| ISR never fires                               | `sei` missing, or `INTCTRL.OVF` not enabled           |
| ISR fires once, then never again              | `INTFLAGS.OVF` not cleared (forgot the W1C write)     |
| Ticks count twice as fast as expected         | CLKSEL set to /8 instead of /16                       |
| Delta is `0` every loop                       | `INTCTRL.OVF` not enabled                             |
| Build fails on `TCA_SINGLE_CLKSEL_DIV16_gc`   | `*_gc` is a C enum — use `(4 << TCA_SINGLE_CLKSEL_gp)` |
| Random delta values that don't match `COUNTER`| `ticks()` not atomic, or r8/r9 clobbered elsewhere     |

For the exact tick-count math behind the 0x65 delta in `main.S`, see
`sysclock_timing.md` — it walks the cycle accounting for the busy-wait loop
plus the per-OVF ISR overhead.
