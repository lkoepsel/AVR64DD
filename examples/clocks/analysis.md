The structure is a single loop with no call/return — every instruction between consecutive `sbi` toggles counts toward the half-period. Walking one trip through `main_loop`:

```
    sbi   VPF_IN, LED    ; 1 cycle   - the toggle (edge appears here)
    nop                  ; 1 cycle
    ldi   temp_20, 32    ; 1 cycle   - runs once per trip
delay_100:
    dec   temp_20        ; 1 cycle   ] repeats
    brne  delay_100      ; 2 taken / 1 fall-through
    rjmp  main_loop      ; 2 cycles  - back to the toggle
```

The `dec`/`brne` pair runs 32 times (counter 32→0). First 31 iterations branch taken: (1 + 2) × 31 = 93. Final iteration falls through: (1 + 1) = 2. Loop subtotal = 95 cycles. Then the fixed instructions: `sbi` (1) + `nop` (1) + `ldi` (1) + `rjmp` (2) = 5. Half-period = **100 cycles exactly** → 100 × 0.25 µs = **25.00 µs**. The `nop` is what trims it to a round 100 — without it you'd be at 99.

One pass through `main_loop` is **exactly 100 cycles** = 25.00 µs per LED level at 4 MHz, so the full square wave is 200 cycles = 50 µs, a clean 20 kHz. The breakdown: the `dec`/`brne` loop is 95 cycles (31 taken branches at 3 cycles each = 93, plus the final fall-through at 2), and the four fixed instructions — `sbi`, `nop`, `ldi`, `rjmp` — add 5, totaling 100.

The lone `nop` is the only tuning instruction — it's what rounds 99 up to 100, and it gives you 0.25 µs of adjustment resolution per `nop` if you ever want to trim the period against the scope.
