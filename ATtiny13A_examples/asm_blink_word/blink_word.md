## Timing Analysis — 16-bit Delay Loop

Here's the full cycle accounting for one complete pass through `main_loop`:

### Instruction-by-Instruction Breakdown

| Instruction | Cycles | Notes |
|---|---|---|
| `sbi IO_PIN, LED` | 2 | Toggle the pin |
| `ldi R25, hi8(counter)` | 1 | Reload high byte |
| `ldi R24, lo8(counter)` | 1 | Reload low byte |
| `sbiw R24, 1` | 2 | 16-bit decrement (×N iterations) |
| `brne delay_loop` (taken) | 2 | Branch back (×N−1 times) |
| `brne delay_loop` (not taken) | 1 | Final iteration, falls through |
| `rjmp main_loop` | 2 | Jump back to top |

---

### The Loop Core

The delay loop itself has two phases:

**Iterations 1 through N−1** (branch taken):
```
sbiw  →  2 cycles
brne  →  2 cycles
──────────────────
         4 cycles per iteration
```

**Final iteration N** (branch not taken):
```
sbiw  →  2 cycles
brne  →  1 cycle
──────────────────
         3 cycles
```

---

### Total Cycle Formula

```
Total = 2          (sbi)
      + 1          (ldi high)
      + 1          (ldi low)
      + 4×(N−1)    (loop body, taken)
      + 3          (loop body, final)
      + 2          (rjmp)
      
      = 4N + 5
```

For **N = 50000**:
```
4 × 50000 + 5 = 200,005 cycles
```

---

### Converting to Time

At 1.2 MHz, one cycle = 1/1,200,000 s:

```
200,005 / 1,200,000 = 0.16667 seconds = ~166.7ms per toggle
```

Since the pin toggles every 166.7ms, the full on/off period is:
```
2 × 166.7ms = 333.4ms  →  ~3.0 Hz blink rate
```

---

### Working Backwards — Finding N for a Target Delay

Rearranging `Total = 4N + 5`:

```
N = (cycles − 5) / 4
```

| Target Delay | Cycles Needed | N (counter value) |
|---|---|---|
| 1ms | 1,200 | 299 |
| 10ms | 12,000 | 2,999 |
| 100ms | 120,000 | 29,999 |
| 500ms | 600,000 | 149,999 — exceeds 16-bit max! |

That last row is the key hardware limitation — a 16-bit counter maxes out at 65,535, giving you:
```
4 × 65535 + 5 = 262,145 cycles
262,145 / 1,200,000 = ~218ms maximum delay
```

So for delays longer than ~218ms at 1.2MHz, you'd need either a nested loop (like your original `delay_1ms` subroutine), a hardware timer, or calling the delay routine multiple times.

Good empirical data — let's work backwards from your measurement and find where the formula is off.

---

## Working Backwards from N = 284

At 1.2MHz, 1ms = 1200 cycles. With N = 284:

```
1200 / 284 = 4.225 cycles per iteration (average)
```

That's not a clean number, which suggests the overhead terms (the non-loop instructions) are significant at small N. Let's solve for the actual overhead:

```
Total cycles = 4×(N−1) + 3 + overhead
1200         = 4×283 + 3 + overhead
1200         = 1132 + 3 + overhead
1200         = 1135 + overhead
overhead     = 65 cycles
```

**65 cycles of overhead is way too high** for just `sbi`, two `ldi`s, and `rjmp`. Something else is being counted.

---

## What Was Missed — The `sbi` and `rjmp` Timing on AVR

Let me re-examine the AVR instruction timing more carefully:

| Instruction | Actual Cycles | Previously Listed |
|---|---|---|
| `sbi IO_PIN, LED` | 2 | 2 ✓ |
| `ldi R25, hi8(counter)` | 1 | 1 ✓ |
| `ldi R24, lo8(counter)` | 1 | 1 ✓ |
| `sbiw R24, 1` | 2 | 2 ✓ |
| `brne` (taken) | 2 | 2 ✓ |
| `brne` (not taken) | 1 | 1 ✓ |
| `rjmp main_loop` | 2 | 2 ✓ |

Those all look right, which means the discrepancy is likely coming from **how you are measuring**. A few questions that would resolve this:

---

## Likely Sources of the Discrepancy

**1. RC Oscillator Accuracy**
The ATtiny13A factory default is nominally 1.2MHz, but the internal RC oscillator is only accurate to **±10%** without calibration. The actual frequency could be anywhere from ~1.08MHz to ~1.32MHz. That alone could shift the measured counter value significantly:

```
At 1.08MHz:  N = (1080 − 5) / 4 = 268
At 1.20MHz:  N = (1200 − 5) / 4 = 299
At 1.32MHz:  N = (1320 − 5) / 4 = 329
```

**2. How are you measuring the 1ms?** If you're using an oscilloscope or logic analyzer on the pin, the measurement is solid. If you're using a frequency counter and calculating back, there may be a division error.

**3. OSCCAL Register**
The ATtiny13A has a calibration register (`OSCCAL`) that trims the RC oscillator. Its factory-programmed value targets 9.6MHz (then divided by 8 for 1.2MHz), but the actual trimmed frequency varies unit-to-unit.

---

## Revised Formula Using Your Measurement

If N = 284 gives exactly 1ms, then the actual cycle count per loop is:

```
1200 = 4×(284−1) + 3 + overhead
overhead = 1200 − 1135 = 65 cycles
```

Or more likely, your oscillator is running faster than 1.2MHz. If we assume the formula `4N + 5` is correct:

```
4×284 + 5 = 1141 cycles
1141 cycles = 1ms  →  actual clock = 1,141,000 Hz ≈ 1.141MHz
```

That's about **5% slow** relative to nominal — well within the ±10% RC oscillator tolerance and a very plausible explanation.

---

## Recommendation

Read the `OSCCAL` register value and post it, or better yet, measure the actual clock frequency directly on the CLKO pin (if enabled) or by timing a known loop. That will tell you definitively whether it's an oscillator accuracy issue or a cycle counting error.

That's a solid instrument — the Analog Discovery 2 is accurate enough that we should trust your 284 measurement and find the error in the cycle count formula instead.

---

## Re-examining the Formula

Let's plug N = 284 into the formula and see what clock frequency it implies:

```
4 × 284 + 5 = 1141 cycles measured as 1ms
→ actual clock = 1,141,000 Hz
```

That's 59kHz slow — plausible for an uncalibrated RC oscillator, but let's also double-check the **loop cycle count itself** by re-reading the ATtiny13A datasheet instruction timing.

---

## The Likely Culprit — `sbiw` Timing

On the ATtiny13A (and AVR generally), `sbiw` is actually **2 cycles**, which I had correct. But let me re-examine `brne`:

The AVR instruction set manual specifies `brne` as:

| Condition | Cycles |
|---|---|
| Branch **not** taken | 1 |
| Branch taken | **2** |

That matches what I had. So the loop body at 4 cycles per iteration should be right.

---

## Re-examining Overhead More Carefully

What does the Analog Discovery 2 actually see? It measures **pin-high or pin-low time** — the time from one `sbi IO_PIN` to the next. Let's retrace exactly what executes between two successive toggles:

```
sbi  IO_PIN, LED        ; 2 cycles  ← AD2 starts timing here
ldi  R25, hi8(counter)  ; 1 cycle
ldi  R24, lo8(counter)  ; 1 cycle
sbiw R24, 1             ; 2 cycles  ─┐
brne delay_loop         ; 2 cycles   │  × (N−1) iterations
                                     │
sbiw R24, 1             ; 2 cycles  ─┘ final iteration
brne delay_loop         ; 1 cycle   (not taken)
rjmp main_loop          ; 2 cycles
                                    ← AD2 stops timing here
```

Total:
```
2 + 1 + 1 + 4×(N−1) + 3 + 2  =  4N + 5
```

So the formula **is** correct at 4N + 5. With N = 284:

```
4 × 284 + 5 = 1141 cycles = 1ms
→ clock = 1.141 MHz
```

---

## Conclusion — It's the Oscillator

The math is consistent. Your ATtiny13A is running at approximately **1.141 MHz**, about 4.9% below the nominal 1.2MHz. This is completely normal — the datasheet specifies the uncalibrated internal RC oscillator at ±10%.

You can verify this directly with the Analog Discovery 2 — if you enable `CLKO` (clock output) on PB4 by clearing the `CKDIV8` fuse or reading `OSCCAL`, you can measure the raw oscillator frequency. Alternatively, a simpler software check: if you set `counter = 1200` and the measured period is not exactly 1ms × (1200/284) = **4.225ms**, the oscillator frequency is the variable.

If you need precise 1ms timing for your students' labs, the fix is to write a calibration value to `OSCCAL` at startup:

```asm
reset_handler:
    ldi     r16, 0x6F       ; example trim value — yours will differ
    out     RCCAL, r16      ; nudge oscillator toward true 1.2MHz
```

The correct `OSCCAL` value is found empirically using the Analog Discovery 2 — adjust until the measured period matches the expected value. Each unit needs its own calibration value, which is why Microchip factory-programs a default into the signature row at address `0x000001`.

The `CLKO` function on PB4 is controlled by a **fuse bit**, not by software registers — so you need to program it through your programmer, not in your assembly code.

---

- **CLKO does not exist on the ATtiny13A**
- The search results I used were pulling information from other AVR devices (ATmega328P, ATtiny85, etc.) and I failed to catch that the information didn't apply to your specific target
- The fuse byte values and pin assignments I gave you were wrong for this device

---

## The Right Way to Measure Your Clock

Since there's no CLKO, your options for measuring the actual oscillator frequency with the Analog Discovery 2 are:

**1. Time a known software loop** — which you've already done empirically. N=284 for 1ms is your best measurement and works backwards to give you the actual clock frequency via `4N + 5` cycles.

**2. Read the `OSCCAL` register value** and compare it to the factory calibration stored in the signature row at address `0x000001`, which you can read with avrdude:
```bash
avrdude -p attiny13a -c usbasp -U signature:r:-:h
```

**3. Toggle a pin at a known rate** using a precisely counted loop and measure that pin with the Analog Discovery 2 — which is effectively what your blink program is already doing.
