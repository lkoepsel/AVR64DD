# AVR Assembly Blink Program — Detailed Analysis

## Overview

This program blinks an LED connected to pin PB0 of an ATtiny13A microcontroller at 500 Hz — toggling the pin every 1ms (1ms on, 1ms off = 2ms period = 500 Hz).

---

## Target Hardware

| Parameter | Value |
|---|---|
| MCU | ATtiny13A |
| Clock | 1.2 MHz (factory default internal RC) |
| LED Pin | PB0 (physical pin 5) |
| Circuit | PB0 → 220Ω resistor → LED → GND |

The ATtiny13A is an 8-bit AVR with **64 bytes of SRAM**, **1KB of Flash**, and a single 8-bit port (PORTB, 6 usable pins).

---

## Section-by-Section Breakdown

### 1. Include Files

```asm
#include <avr/io.h>
#include "registers.S"
```

Because the source is named `main.S` (uppercase) and assembled by `avr-gcc`, the C preprocessor runs first — so `#include` works exactly as it does in C.

`avr/io.h` is the avr-libc device-definition header. It provides symbolic names for every special-purpose register and bit position — `DDRB`, `PORTB`, `PINB`, `PB0`, `RAMEND`, `SPL`, `SREG`, etc. Without it, you'd have to use raw I/O addresses.

`registers.S` is a small Library header that layers logical, application-specific names on top — `LED`, `IO_DDR`, `IO_PIN`, `STACK_LOW`, `STATUS` — each wrapping its register in the `_SFR_IO_ADDR()` macro so it can be used with the `in`/`out`/`sbi`/`cbi` instructions.

---

### 2. Interrupt Vector Table

```asm
.section .vectors, "ax", @progbits
    rjmp    reset_handler       ; 0x000  RESET
    reti                        ; 0x001  INT0
    reti                        ; 0x002  PCINT0
    ...
    reti                        ; 0x009  ADC
```

The ATtiny13A has **10 interrupt vectors**, each occupying one 16-bit word at the start of Flash. The linker places this section at address `0x000`.

- **`rjmp reset_handler`** — The RESET vector (address `0x000`) jumps to the startup code. This is the entry point after power-on, external reset, or watchdog reset.
- **`reti`** (Return from Interrupt) — All other vectors are stubbed out. If any of these interrupts somehow fire (they shouldn't, since none are enabled), `reti` safely returns without side effects. This is better practice than leaving vectors empty, which could cause runaway execution on some AVR variants.

> **LC-3 Parallel:** This is conceptually similar to the LC-3's interrupt vector table at `0x0100`–`0x01FF`, where each entry points to a service routine. The key difference is that AVR vectors are at the *very start* of Flash and are fixed in hardware.

---

### 3. Reset Handler — Startup/Initialization

```asm
reset_handler:
    ldi     r16, lo8(RAMEND)
    out     STACK_LOW, r16            ; ATtiny13A has no SPH
```

**Stack pointer initialization.** `RAMEND` on the ATtiny13A is `0x9F` (the last byte of its 64-byte SRAM). `lo8()` extracts the low byte (the full value fits in 8 bits here anyway). The Stack Pointer is set to the top of SRAM so `rcall`/`ret` work correctly.

The ATtiny13A only has `SPL` (Stack Pointer Low) — no `SPH` — because 64 bytes of RAM doesn't need a 16-bit pointer.

```asm
    eor     r1, r1
    out     STATUS, r1
```

**Register and status flag initialization.** `eor r1, r1` XORs r1 with itself, producing zero (2 birds, 1 stone: zeros r1 *and* sets the Zero flag). Then that zero is written to the Status Register (`STATUS`), clearing all flags (Carry, Zero, Negative, Overflow, Sign, Half-carry, Transfer, Interrupt). `r1` is conventionally reserved as the "zero register" in AVR-GCC ABI — zeroing it here respects that convention.

```asm
    sbi     IO_DDR, LED         ; PB0 as output
```

**GPIO direction configuration.** `sbi` (Set Bit in I/O register) sets bit `LED` (PB0, bit 0) of `IO_DDR`, the Data Direction Register for Port B. A `1` in `IO_DDR` means output; `0` means input. After this instruction, PB0 is configured as a digital output. All other PORTB pins remain inputs (`IO_DDR` defaults to `0x00` on reset).

---

### 4. Main Loop

```asm
main_loop:
    sbi     IO_PIN, LED         ; toggle LED
    rcall   delay_1ms
    rjmp    main_loop
```

This is an infinite loop — the AVR equivalent of `while(1)` in C.

**The toggle trick — `sbi IO_PIN, LED`:**
This is a non-obvious but well-documented AVR feature. On most AVRs you'd toggle an output by XORing PORTB. But the ATtiny13A (and other modern AVRs) implement a hardware shortcut: **writing a `1` to a bit in the PIN register toggles the corresponding PORTB output bit** atomically in a single instruction. This is faster and more concise than the read-modify-write sequence:
```asm
; The "old" way to toggle:
in  r16, IO_PORT
ldi r17, (1 << LED)
eor r16, r17
out IO_PORT, r16        ; 4 instructions vs 1
```

**`rcall delay_1ms`** — calls the delay subroutine (discussed below).  
**`rjmp main_loop`** — unconditional relative jump back to the top. Since the ATtiny13A has only 1KB of Flash, `rjmp` (±2KB range) is always sufficient — `jmp` (the 4-byte long jump) is unnecessary and unavailable on this device anyway.

Result: the LED toggles every 1ms → 500 Hz blink.

---

### 5. Delay Subroutine — Cycle Counting

```asm
delay_1ms:
    ldi     r17, 2
outer:
    ldi     r16, 189
inner:
    dec     r16
    brne    inner
    dec     r17
    brne    outer
    ret
```

Since the ATtiny13A has no hardware timer being used here, the delay is implemented as a **software busy-wait loop** — burning CPU cycles deliberately.

**The math:**

At 1.2 MHz, one clock cycle = 1/1,200,000 s ≈ 0.833 µs. We need ~1200 cycles for 1ms.

Let's count the cycles for each instruction:

| Instruction | Cycles |
|---|---|
| `ldi r17, 2` | 1 |
| `ldi r16, 189` | 1 (×2 outer iterations) |
| `dec r16` | 1 (×189 per outer) |
| `brne inner` (taken) | 2 (×188 per outer) |
| `brne inner` (not taken) | 1 (×1, last iteration) |
| `dec r17` | 1 (×2) |
| `brne outer` (taken) | 2 (×1) |
| `brne outer` (not taken) | 1 (×1, last) |
| `ret` | 4 |

**Inner loop** (per outer iteration):
- `ldi r16, 189`: 1 cycle
- `dec` + `brne` taken: (1+2) × 188 = 564 cycles
- `dec` + `brne` not taken (last): (1+1) = 2 cycles
- `dec r17`: 1 cycle

Inner loop total per outer iteration: 1 + 564 + 2 + 1 = **568 cycles**

**Full delay:**
- 2 outer iterations × 568 = 1136
- `ldi r17, 2`: 1
- Final `brne outer` not taken: 1
- `ret`: 4

**Total ≈ 1142 cycles** → 1142 / 1,200,000 ≈ **0.952 ms**

The comment says 1.004ms "measured" — the small discrepancy likely comes from `rcall` (3 cycles) and the `sbi` (2 cycles) overhead in the calling loop being factored into the real-world measurement, or from the RC oscillator running slightly above 1.2 MHz.

> **LC-3 Parallel:** LC-3 programmers will recognize this pattern from trap routine timing loops — the same principle of counting instruction cycles to produce a known time delay. The key difference is that LC-3 instructions are all 1 cycle in the simulator, while AVR instructions are 1–4 cycles depending on the instruction.

---

### 6. Data Sections

```asm
.section .data
.section .bss
```

Both are **empty** — this program uses no initialized global variables (`.data`) and no uninitialized global variables (`.bss`). They're declared explicitly to satisfy the linker and follow standard ELF section conventions.

---

## Memory Map Summary

| Region | Usage |
|---|---|
| Flash `0x000` | Interrupt vector table (10 words) |
| Flash `0x00A`+ | `reset_handler`, `main_loop`, `delay_1ms` |
| SRAM `0x60`–`0x9F` | Stack (grows downward from `RAMEND = 0x9F`) |
| I/O `0x17` (DDRB) | PB0 set to output |
| I/O `0x16` (PINB) | Written to toggle PB0 |

---

## Key AVR Concepts Demonstrated

1. **Harvard architecture** — separate program (Flash) and data (SRAM) address spaces, unlike the LC-3's von Neumann model
2. **I/O register manipulation** — `sbi`/`out` access the I/O space (addresses `0x00`–`0x3F`) directly, bypassing the general data bus
3. **The PIN toggle trick** — atomic single-cycle output toggle via the PIN register
4. **Software delay loops** — cycle-counted busy-wait without using timers
5. **Minimal ISR stubs** — `reti` placeholders for unused interrupt vectors
6. **Stack initialization** — explicit SP setup required; the hardware doesn't do it for you (unlike many modern ARM Cortex-M devices)
7.
