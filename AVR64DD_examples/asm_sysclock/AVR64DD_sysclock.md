# AVR64DD32 Sysclock

## Comparison to ATtiny13A sysclock
The ATtiny13A uses Timer0 in CTC mode with COMPA; the AVR64DD32 has the much richer TCA0 peripheral, and you specifically asked for the **OVF (overflow) interrupt** rather than compare-match. So this is TCA0 in normal mode, counting to PER, firing OVF. The vector is `TCA0_OVF_vect`, and the register model is entirely different (memory-mapped, `lds`/`sts`, not `in`/`out` for most of it). I'll keep your tick-counter ISR structure, your comment banners, your "Registers and Values" block, and the standalone-assembly approach. No AVR toolchain in this environment, so I can't assemble-test it here or verify the exact register addresses against the header — which means I'll write it carefully against the known AVR64DD32 / AVR-Dx register model and flag the specific values for you to confirm with `grep` on your RPi before relying on them. Let me write the program.A companion to your tiny13 module, built around TCA0's overflow interrupt as you asked. It keeps your conventions — the banner header, the "Registers and Values" block, dedicated low registers for the ISR (`ISR_temp`, `ticks_lo`, `ticks_hi`) so the ISR stays short, the `movw`-based `ticks` return, and the standalone-assembly structure with the three sections.

## Changes from ATtiny13, and why:

The big structural shift is **OVF instead of COMPA**. TCA0 in NORMAL mode counts 0→PER and fires overflow on rollover, so the timing is set by PER rather than OCR0A. I worked the math for the AVR64DD32's 4 MHz post-reset clock and chose prescale /16 with PER=249, which gives an *exact* 1.000 ms tick — the comment block shows the arithmetic and an alternate /64 option so you can teach the tradeoff.

The register access model is the other teaching point: TCA0 is **memory-mapped**, so it's `lds`/`sts`, not `in`/`out`. Only SREG stays as `in`/`out` (via `CPU_SREG`).

Two AVR-Dx specifics: the ISR **clears OVF by writing 1** to the INTFLAGS bit (write-1-to-clear, unlike the tiny13 where the flag auto-clears), and `init` enables the interrupt through `INTCTRL` then starts the timer by writing `CLKSEL | ENABLE` to `CTRLA`. I also made `ticks` do an atomic `cli`/`movw`/restore read, since a 16-bit counter can tear if an overflow lands mid-read.

The things you must verify on the RPi before relying on it — I couldn't assemble-test here (no AVR toolchain in this environment) and these are device-specific:

The **vector number**. I used `__vector_8` for `TCA0_OVF_vect`, but confirm it: `grep TCA0_OVF_vect /path/to/ioavr64dd32.h` — it'll show `_VECTOR(n)`, and `n` must match. A wrong vector number is the most likely failure, and it fails silently (ISR never runs).

The **symbol names** — `TCA0_SINGLE_PERL`, `TCA0_SINGLE_CTRLA`, `TCA_SINGLE_CLKSEL_DIV16_gc`, `TCA_SINGLE_OVF_bm`, etc. The AVR-Dx headers expose the peripheral both as a struct (`TCA0.SINGLE.PER`) and, in many versions, as flat `sts`-able symbols. If avr-as doesn't recognize the flat `TCA0_SINGLE_PERL` names, the fix is to use the numeric addresses directly (the same ones your gdb-dashboard peripheral module will use), and I can rewrite it that way — tell me what `grep TCA0_SINGLE_PER /path/to/ioavr64dd32.h` returns and I'll match it.

There's a satisfying loop back to your dashboard work here: this program drives exactly the TCA0 registers (CTRLA, CTRLB, PER, CNT) that your `AvrPeripheral` module displays — so once it's running, stepping through `init_sysclock_1k` with the dashboard up lets students watch CTRLA's ENABLE bit flip and CNT start climbing live. Want me to add a tiny `main.S` that calls `init_sysclock_1k` and spins, plus a matching vector-table stub, so it's a complete flashable example for that demo? And if you paste the `grep` output for the TCA0 symbols, I'll lock the names to your header.

Good — vector 9, not 8. That's exactly the kind of thing that has to come from the header, not memory. One required fix in this file, then I'll lay out the vector-table side.

First, correct this module: change `__vector_8` to `__vector_9` (both the `.global` and the label). The `address 0x12` confirms it — AVR vectors are spaced 2 bytes apart on this part (each is an `rjmp`/`jmp` slot), and vector 9 × 2 = 0x12. Consistent.

Now, what your calling program's vector table needs. The mechanism: at reset the CPU jumps to address 0x0000, where there's a table of jump instructions — one slot per vector, in vector-number order. Slot 0 is RESET, and slot 9 (at byte 0x12) must jump to your TCA0_OVF handler. Everything hinges on the handler's name matching what the table references.

You have two ways to wire it, and which you pick depends on how the rest of your class's programs are built.

**Option A — the toolchain/CRT builds the table for you (recommended if you link against the standard AVR runtime).** The C runtime (`crt<device>.o`, pulled in automatically by avr-gcc) already contains a complete weak vector table. Each slot does an `rjmp` to a weak default symbol named `__vector_N`. By naming your ISR `.global __vector_9`, you *override* the weak default, and the prebuilt table's slot 9 now jumps to your handler. That's the whole point of the `__vector_9` naming in the module — it's designed to slot into the CRT's table with zero table code on your side.

In this case your calling program does **nothing special** for the vector table. You just:
- link normally with avr-gcc (so the CRT is included), and
- make sure the object file with `__vector_9` is in the link.

That's it. The `sei` in `init_sysclock_1k` enables interrupts globally; the table routing is already handled.

**Option B — you hand-roll the vector table in pure assembly (if your class builds without the CRT, e.g. `-nostartfiles`).** Then you must write the table yourself at the start of `.text`, placed at address 0. It looks like this — a calling `main.S` skeleton:

```asm
#include <avr/io.h>

; ---- Vector table at 0x0000 ----
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    rjmp  reset            ; vector 0  - RESET
    rjmp  __bad_interrupt  ; 1
    rjmp  __bad_interrupt  ; 2
    rjmp  __bad_interrupt  ; 3
    rjmp  __bad_interrupt  ; 4
    rjmp  __bad_interrupt  ; 5
    rjmp  __bad_interrupt  ; 6
    rjmp  __bad_interrupt  ; 7
    rjmp  __bad_interrupt  ; 8
    rjmp  TCA0_OVF_handler ; 9  - TCA0 OVF   <-- the one you need
    ; ... remaining slots can stay __bad_interrupt unless used
```

A few things that matter for Option B on the AVR64DD32 specifically:

The reset/vector base. On AVR-Dx parts the vector table location is controlled, and by default starts at 0x0000 in flash — but the device has the `IVSEL`/boot-vs-app section concept. For a flat single-section program loaded by Bloom this defaults correctly to 0, so a normal `.vectors` section at the start links right. If you've set any `BOOTSIZE`/`CODESIZE` fuses, that changes the base — worth a glance but not normally an issue for classroom flat builds.

`__bad_interrupt` conventionally jumps to the reset handler (or to a halt loop). If you're fully bare-metal you can define it as a `reti` or an `rjmp` to itself for a "trap unexpected interrupt" teaching behavior.

The table uses `rjmp` (2-byte slots), which matches your "address 0x12 for vector 9" — `rjmp` reach covers the whole AVR64DD32 flash so you don't need the 4-byte `jmp` form.

**Which one applies to you?** Your tiny13 module's comment — *"`__vector_6` overrides the CRT's weak symbol… `TIM0_COMPA_handler` is kept as an alias so pure-asm main.S vector tables still link"* — tells me you actually support **both** paths deliberately: the `__vector_N` name for CRT-linked C builds, and the readable alias (`TCA0_OVF_handler`) for pure-asm tables. The DD32 module already mirrors that, so you're covered either way. For Option A you reference `__vector_9` (automatic); for Option B your hand-written table references `TCA0_OVF_handler` (the alias), exactly as your tiny13 `main.S` references `TIM0_COMPA_handler`.

So concretely, the only edit needed in the module is `8 → 9`. Let me make it:Now let me give you a complete `main.S` calling skeleton so you have a flashable example. I'll write it the pure-asm way (Option B) since that matches how your tiny13 `main.S` works with the alias — and it's the more instructive version for the class:Both files updated. The module now uses `__vector_9`, and `main_dd32.S` gives you the calling side with the hand-rolled vector table.

The short answer to your question — what the calling program does to init the vectors — depends on which build path you use, and your tiny13 module shows you already support both:

**Pure-asm build (the `main_dd32.S` I wrote):** the calling program *is* the vector table. The `.vectors` section at flash 0x0000 is a list of `rjmp` slots in vector-number order; slot 9 (byte 0x12, matching what your header told you) does `rjmp TCA0_OVF_handler`, routing the overflow to the ISR via its readable alias. Slots you don't use point at `__bad_interrupt`, which spins in place so a stray interrupt is visible under the debugger rather than silently resetting. Reset sets the stack pointer to RAMEND, calls `init_sysclock_1k`, and loops calling `ticks`.

**CRT-linked build (avr-gcc + standard runtime):** you do *nothing* for the table. The runtime already ships a complete weak vector table whose slot 9 jumps to the weak symbol `__vector_9`; because the ISR declares `.global __vector_9`, it overrides the weak default and the existing table now points at your handler. No `.vectors` section needed — `main` is just the stack setup, the `init` call, and the loop. This is the path the `__vector_9` naming exists for.

The slot count detail worth teaching: AVR-Dx vectors are 2-byte `rjmp` slots, which is why vector 9 sits at 0x12 (9 × 2). `rjmp` reaches across the whole 64 KB flash, so you never need the 4-byte `jmp` form on this part.

Two things to confirm when you assemble, same caveats as before since I couldn't build it here:

The TCA0 symbol names (`TCA0_SINGLE_PERL`, `TCA0_SINGLE_CTRLA`, `TCA_SINGLE_CLKSEL_DIV16_gc`, etc.) — if avr-as rejects any flat `TCA0_SINGLE_*` name, paste `grep TCA0_SINGLE_CTRLA /path/to/ioavr64dd32.h` and I'll switch those to the exact symbols or numeric addresses your header uses.

`CPU_SPL`/`CPU_SPH`/`CPU_SREG` — these are the AVR-Dx names for the stack-pointer and status registers; if your header exposes them unprefixed (`SPL`/`SPH`/`SREG`), adjust the four `out`/`in` lines accordingly.

Once it assembles and flashes, the payoff ties back to your dashboard: set a breakpoint at `main_loop`, and students watch `r25:r24` climb about 1000 counts per second while the `AvrPeripheral` module shows `TCA0.CNT` cycling 0→249 and `TCA0.CTRLA` with the ENABLE bit set — the ISR, the timer, and the tick counter all visible at once over headless SSH.