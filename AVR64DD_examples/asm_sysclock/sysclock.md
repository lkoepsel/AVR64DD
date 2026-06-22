# Claude analysis of sysclock timing loop

* Count = 30,000 => ~100 ms window
* OCR0A = 0x95 or 149
* Prescaler = /8

Result = 0x65 or 101

The ISR uses `r2` as a dedicated scratch register (reserved globally — see the
register notes at the top of `main.S`), so it needs no `push`/`pop`. That keeps
the per-interrupt overhead to 15 cycles.

## Analysis

Confirmed — 0x65 (101) is the right number. Here's why it's 101 and not the "obvious" 100.

  Tick period (how often r9:r8 — `ticks_hi:ticks_lo` — increments)

  ┌─────────────────────────┬─────────────────────────────┐
  │          Item           │            Value            │
  ├─────────────────────────┼─────────────────────────────┤
  │ OCR0A                   │ 0x95 = 149                  │
  ├─────────────────────────┼─────────────────────────────┤
  │ CTC TOP period          │ 1 + 149 = 150 timer counts  │
  ├─────────────────────────┼─────────────────────────────┤
  │ Prescaler (CS01)        │ ÷8                          │
  ├─────────────────────────┼─────────────────────────────┤
  │ CPU cycles per tick     │ 150 × 8 = 1200              │
  ├─────────────────────────┼─────────────────────────────┤
  │ Time per tick @ 1.2 MHz │ 1200 / 1,200,000 = 1.000 ms │
  └─────────────────────────┴─────────────────────────────┘

  Delay loop — instruction cycles

  ┌──────────────────────────────────────┬───────────┐
  │             Instruction              │  Cycles   │
  ├──────────────────────────────────────┼───────────┤
  │ sbiw r26,1                           │ 2         │
  ├──────────────────────────────────────┼───────────┤
  │ brne taken                           │ 2         │
  ├──────────────────────────────────────┼───────────┤
  │ → per normal iteration               │ 4         │
  ├──────────────────────────────────────┼───────────┤
  │ Final iteration (brne falls through) │ 2 + 1 = 3 │
  ├──────────────────────────────────────┼───────────┤
  │ Total: 29,999 × 4 + 3                │ 119,999   │
  └──────────────────────────────────────┴───────────┘

  Naïvely: 119,999 / 1200 = 99.99 ≈ 100 ticks. So where does the extra ~1 come from?

  ISR cost per invocation

  The interrupt doesn't change the timer, but it does steal CPU cycles from the loop — so the loop's wall-clock time is longer than its instruction count.

  ┌──────────────────────────────────────┬────────┐
  │                 Step                 │ Cycles │
  ├──────────────────────────────────────┼────────┤
  │ Interrupt latency (PC push + vector) │ 4      │
  ├──────────────────────────────────────┼────────┤
  │ rjmp TIM0_COMPA_handler              │ 2      │
  ├──────────────────────────────────────┼────────┤
  │ in r2, STATUS                        │ 1      │
  ├──────────────────────────────────────┼────────┤
  │ inc r8                               │ 1      │
  ├──────────────────────────────────────┼────────┤
  │ brne done (taken, common case)       │ 2      │
  ├──────────────────────────────────────┼────────┤
  │ inc r9 (carry only — skipped here)   │ 0      │
  ├──────────────────────────────────────┼────────┤
  │ out STATUS, r2                       │ 1      │
  ├──────────────────────────────────────┼────────┤
  │ reti                                 │ 4      │
  ├──────────────────────────────────────┼────────┤
  │ Total per ISR                        │ 15     │
  └──────────────────────────────────────┴────────┘

  On the rare carry path (once every 256 ticks, when `r8` wraps from 0xFF to
  0x00), `brne` falls through (1 cycle) and `inc r9` executes (1 cycle) — the
  same 15-cycle total.

  Because `r2` and the counter `r9:r8` are reserved registers, the handler skips the usual `push`/`pop` pair — an r16-based handler that saved/restored r16 on the stack would add 4 cycles (push + pop) for a total of 19 cycles; this one costs 15.

  Putting it together

  Wall-clock time of the loop = loop instructions + every ISR that fires during it:

  T_wall = 119,999 + 15 · n      where  n = T_wall / 1200

  Solving the fixed point:

  T_wall = 119,999 / (1 − 15/1200) = 119,999 × 1200/1185 ≈ 121,518 cycles
  n      = 121,518 / 1200 ≈ 101.3 ticks

  ┌──────────────────────────┬──────────┬───────────────┐
  │                          │  Cycles  │     Ticks     │
  ├──────────────────────────┼──────────┼───────────────┤
  │ Delay loop instructions  │ 119,999  │ 100.0         │
  ├──────────────────────────┼──────────┼───────────────┤
  │ ISR overhead (~101 × 15) │ ~1,515   │ ~1.3          │
  ├──────────────────────────┼──────────┼───────────────┤
  │ Total measured window    │ ~121,518 │ ≈ 101.3 → 101 │
  └──────────────────────────┴──────────┴───────────────┘

  The count of compare-matches inside a ~121,518-cycle window is 101–102 depending on phase; since the loop starts deterministically relative to the timer, you get a consistent 101 = 0x65. ✓

  Note r7 (delta high byte) prints as 0x00 — correct, since 101 fits in one byte.
  COUNTER = 30000 is deliberately a ~100 ms window so the delta is visible. If you ever want delta ≈ exactly 100, you'd need to shave the loop to compensate for the 14-cycle-per-tick ISR tax.
