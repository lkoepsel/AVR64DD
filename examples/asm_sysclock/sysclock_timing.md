# sysclock timing — counting ticks during a busy wait

`main.S` in this directory exists to demonstrate that the sysclock ISR keeps
running while main-line code is busy. It snapshots `ticks`, busy-waits
`COUNTER` iterations of a 2-instruction loop, snapshots `ticks` again, and
sends the delta over USART0. This page derives the expected delta from first
principles so you can pick a `COUNTER` that gives a meaningful number on the
serial display.

The reference implementation is `main.S` (the busy-wait loop) and
`Library/sysclock.S` (the 1 kHz TCA0 OVF ISR).

---

## 1. The numbers that go into the calculation

| Quantity                       | Value                                  |
|--------------------------------|----------------------------------------|
| `F_CPU`                        | 4 000 000 Hz (post-reset OSCHF)        |
| TCA0 prescale                  | /16                                    |
| TCA0 `PER`                     | 249                                    |
| Tick period (cycles)           | 16 × (249 + 1) = **4000 cycles**       |
| Tick period (time)             | 4000 / 4 000 000 = **1.000 ms** exact  |
| `COUNTER` in `main.S`          | 30 000                                 |

So at the default settings, one tick = 1 ms, and the ISR fires every 4000 CPU
cycles regardless of what main-line code is doing.

---

## 2. Busy-wait loop cost (instruction cycles only)

The loop in `main.S`:

```
    ldi   r27, hi8(COUNTER)
    ldi   r26, lo8(COUNTER)
delay_1ms:
    sbiw  r26, 1
    brne  delay_1ms
```

| Instruction                | Cycles |
|----------------------------|--------|
| `sbiw r26, 1`              | 2      |
| `brne` (taken)             | 2      |
| Normal iteration total     | **4**  |
| Final iteration (fallthru) | 3      |

For `COUNTER = 30 000`:

```
loop_cycles = 29 999 × 4 + 3 = 119 999 cycles
```

That's the cost of the loop *if no interrupts fired*. They will.

---

## 3. ISR cost per overflow

The TCA0 OVF handler in `sysclock.S`, common (no carry) path:

| Step                                       | Cycles |
|--------------------------------------------|--------|
| Interrupt latency (PC push + vector fetch) | 4      |
| `rjmp TCA0_OVF_handler` (from `.vectors`)  | 2      |
| `in   ISR_temp, CPU_SREG`                  | 1      |
| `ldi  temp_16, TCA_SINGLE_OVF_bm`          | 1      |
| `sts  TCA0_SINGLE_INTFLAGS, temp_16`       | 2      |
| `inc  ticks_lo`                            | 1      |
| `brne 1f` (taken — no carry)               | 2      |
| `out  CPU_SREG, ISR_temp`                  | 1      |
| `reti`                                     | 4      |
| **Total per ISR**                          | **18** |

On the rare carry path (every 256 ticks, when `ticks_lo` wraps), `brne` falls
through (1 cycle) and `inc ticks_hi` executes (1 cycle) — same 18-cycle total.

Because `r2` (`ISR_temp`) and `r9:r8` (`ticks_hi:ticks_lo`) are reserved
globally, the handler does no `push`/`pop`. A handler that had to save/
restore `r16` would add 4 cycles (2 + 2), costing 22 cycles per fire.

---

## 4. Putting them together

The timer keeps counting whether the CPU is in the ISR or not, so a tick
still happens every 4000 cycles of wall-clock time. The ISR adds 18 of those
cycles to the busy-wait's wall-clock cost.

Let `T_wall` be total cycles spent in the loop, and `n` the number of OVF
interrupts that fire during it:

```
T_wall = loop_cycles + 18 · n
n      = T_wall / 4000
```

Solving the fixed point:

```
T_wall = 119 999 / (1 − 18/4000)
       = 119 999 × 4000 / 3982
       ≈ 120 542 cycles

n      = 120 542 / 4000
       ≈ 30.14 ticks
```

So the printed delta should be **30** (0x1E) — possibly 31 depending on
where the phase of the busy-wait lands relative to the next overflow.

| Bucket                     | Cycles    | Ticks |
|----------------------------|-----------|-------|
| Loop instructions          | 119 999   | 30.00 |
| ISR tax (~30 × 18)         | ~540      | 0.14  |
| **Total measured window**  | ~120 542  | **≈30**|

`r7` (delta high byte) prints as `0x00`; only `r6` carries a value.

---

## 5. Picking a `COUNTER` that prints a useful number

Solve for `COUNTER` given a desired delta `n` (in ticks):

```
loop_cycles = 4 · COUNTER − 1         (approx, ignoring the −1 from fallthru)
T_wall      = loop_cycles + 18 · n
n           = T_wall / 4000

  ⇒  COUNTER ≈ (4000 · n − 18 · n) / 4
            = n · 995.5
```

Worked targets at the default 1 ms tick:

| Desired delta | Suggested `COUNTER` | Expected printed bytes |
|---------------|---------------------|------------------------|
| 0x10  (16)    | 15 928              | `BB 00 10 EE`          |
| 0x32  (50)    | 49 775              | `BB 00 32 EE`          |
| 0x64  (100)   | 99 550              | `BB 00 64 EE` (`uint16`) |
| 0x80  (128)   | 127 424             | `BB 00 80 EE`          |
| 0xFF  (255)   | 253 853             | last 1-byte delta      |
| 0x0100 (256)  | 254 848             | `BB 01 00 EE` (carry)  |

`COUNTER` is a 16-bit immediate stored via `ldi r27:r26`, so it must fit in
65535. For deltas above ~65 (`COUNTER ≈ 64 700`), nothing changes. For
deltas that won't fit in 16-bit `COUNTER`, either chain two `sbiw` loops or
raise the tick period.

---

## 6. What changes if you retune the sysclock

If you change PER or prescale (see `AVR64DD_sysclock.md` §6), the
cycles-per-tick number above changes; redo the algebra in §4 with the new
`tick_cycles`:

```
tick_cycles = prescale · (PER + 1)
T_wall      = loop_cycles + 18 · n
n           = T_wall / tick_cycles
```

For example, at prescale /64, PER = 62 (≈1.008 ms tick at 4 MHz):

```
tick_cycles = 64 · 63 = 4032
n           = 119 999 / (4032 − 18)
            ≈ 29.9 ticks
```

— essentially the same delta because the tick period barely moved. To see
the busy-wait take noticeably *more* ticks, lower the tick period (e.g.
prescale /4, PER = 99, giving a 100 µs tick at 4 MHz — the delta jumps to
~300, which overflows the 1-byte `r6` print and is why `r7` exists).

If you change `F_CPU` (e.g. switch to 24 MHz via CLKCTRL), every cycle count
on this page stays the same — they're in CPU cycles, not seconds. What
changes is wall-clock time per cycle.
