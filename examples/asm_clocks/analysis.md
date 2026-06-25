Good measurement to reason through. Let me account for the cycles in one full toggle period, because what your scope sees is the time the LED stays in one state — which is one trip through `main_loop` — and that's more than just the delay loop.

First the clock baseline: at 4 MHz, one cycle = 0.25 µs. So 25 µs ≈ 100 cycles. Your comment estimates ~93; let me get the exact count.

**The delay loop.** This is the bulk of the time:

```
    ldi  temp_20, 31     ; 1 cycle, runs once
d_outer:
    dec  temp_20         ; 1 cycle
    brne d_outer         ; 2 cycles when it branches, 1 when it falls through
    ret                  ; 4 cycles (AVR-Dx, see note)
```

The `dec`/`brne` pair runs 31 times. On the first 30 iterations the branch is taken: `dec` (1) + `brne` taken (2) = 3 cycles each → 30 × 3 = 90. On the 31st iteration the counter hits zero, `brne` falls through: `dec` (1) + `brne` not taken (1) = 2 cycles. So the loop body is 90 + 2 = **92 cycles**, plus the `ldi` at **1 cycle** = 93 cycles inside the delay before `ret`. That matches your comment's 93.

**But the period your scope measures includes more than the delay.** One full iteration of `main_loop` — the time the LED holds a level — is everything between consecutive `sbi` toggles:

```
    sbi   VPF_IN, LED    ; the toggle
    rcall delay_250ms    ; call + body + ret
    rjmp  main_loop      ; back to the top
```

Adding the per-loop overhead around the delay:

- `sbi` (toggle via writing the IN register) — **1 cycle** on the AVR-Dx core
- `rcall delay_250ms` — **3 cycles** on these parts (2-byte PC)
- inside: `ldi` + loop = 93 cycles
- `ret` — **4 cycles** on the AVR-Dx core
- `rjmp main_loop` — **2 cycles**

Total per half-period: 1 + 3 + 93 + 4 + 2 = **103 cycles** → 103 × 0.25 µs = **25.75 µs**.

So the 25 µs you measure is really ~25.75 µs per level, and the full square-wave period (high + low) is about 51.5 µs, ~19.4 kHz. The delay loop alone (93 cyc, 23.25 µs) undercounts because the `sbi`, `rcall`, `ret`, and `rjmp` add 10 cycles (2.5 µs) of overhead each time around.

Two things worth flagging, one a cycle-count subtlety and one a naming nit:

The **`rcall`/`ret` cycle counts** are the place to double-check against the datasheet for this specific core, because they differ across AVR families. On the AVR-Dx (the "AVRxt" instruction-timing variant), `rcall` is 3 cycles and `ret` is 4. On classic AVRs `ret` is 4 but some cores list `rcall` as 3–4 depending on flash size. If your scope shows the period a touch longer or shorter than 25.75 µs, the `rcall`/`ret` figures are the most likely cause, and you can back out the true numbers by comparing measured period to the loop count — a nice exercise to do with students against the scope.

The **`sbi VPF_IN, LED` toggle** relies on the AVR-Dx feature where writing a 1 to a bit in the PORTx.IN register toggles the corresponding output — that's the `sbi` taking 1 cycle and producing the edge. Worth confirming `VPF_IN` maps to PORTF.IN in your `registers.S`, since that toggle-on-write behavior is what makes the single-instruction toggle work.
