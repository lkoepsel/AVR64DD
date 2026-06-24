# Using peripheral *group codes* (`*_gc`) from AVR64DD32 assembly

When you configure a modern-AVR peripheral in **C**, you usually drop a tidy
enum constant into a register:

```c
PORTMUX.USARTROUTEA = PORTMUX_USART0_ALT3_gc;   /* route USART0 to PD4..PD7 */
```

The same line written in **assembly** does *not* work — the symbol
`PORTMUX_USART0_ALT3_gc` is invisible to the assembler. This page explains why,
and gives the correct, repeatable pattern for `.S` files.

> TL;DR — the `*_gc` values live in a C `enum`, which the assembler never sees.
> Rebuild the value yourself from the assembler-visible `#define`s:
> **`(numeric_code << PERIPH_FIELD_gp)`**.

---

## Background: peripheral pins are chosen by a multi-bit *field*

On the AVR Dx / megaAVR-0 parts, many peripheral signals can be routed to
different physical pins through the **PORTMUX** registers. The selection is a
small bit *field* inside a register. For USART0 it is the 3-bit field in
`PORTMUX.USARTROUTEA` — from `ioavr64dd32.h`:

```c
typedef enum PORTMUX_USART0_enum {
    PORTMUX_USART0_DEFAULT_gc = (0x00<<0),  /* PA0, PA1, PA2, PA3 */
    PORTMUX_USART0_ALT1_gc    = (0x01<<0),  /* PA4, PA5, PA6, PA7 */
    PORTMUX_USART0_ALT2_gc    = (0x02<<0),  /* PA2, PA3 */
    PORTMUX_USART0_ALT3_gc    = (0x03<<0),  /* PD4, PD5, PD6, PD7 */
    PORTMUX_USART0_ALT4_gc    = (0x04<<0),  /* PC1, PC2, PC3 */
    PORTMUX_USART0_NONE_gc    = (0x05<<0)   /* Not connected to any pins */
} PORTMUX_USART0_t;
```

So **ALT3 = numeric code 3 → PD4–PD7**, and **ALT1 = code 1 → PA4–PA7**. Pick
the wrong code and you silently route the peripheral to the wrong pins — no
warning, no error, it just doesn't work on the bench.

---

## Two symbol families in the header

For every bit field, avr-libc emits **two different kinds** of symbol. The
distinction is the whole story:

| Suffix | Example | Defined as | Meaning |
| ------ | ------- | ---------- | ------- |
| `*_gc` | `PORTMUX_USART0_ALT3_gc` | **member of a C `enum`** | the ready-to-use, already-shifted **value** (group **c**ode) |
| `*_gp` | `PORTMUX_USART0_gp` (= `0`) | **`#define`** | group **p**osition — LSB offset of the field |
| `*_gm` | `PORTMUX_USART0_gm` (= `0x07`) | **`#define`** | group **m**ask — all bits of the field |

The same split applies to single bits: `*_bm` (bit mask) / `*_bp` (bit position)
are `#define`s; there is no single-bit enum.

---

## Why the assembler can't see `*_gc`

A `.S` (capital-S) file is built in two stages:

1. **C preprocessor (`cpp`)** runs first. It handles `#include`, `#define`, and
   macro expansion. After `#include <avr/io.h>`, every `#define` is expanded to
   a literal the assembler then sees:
   `PORTMUX_USART0_gp` → `0`, `PORTMUX_USART0_gm` → `0x07`, register addresses,
   `*_bm`, `*_bp`, … all available.
2. **Assembler (`avr-as` / GAS)** assembles the preprocessed text.

A C `enum { ... }` is **not** a preprocessor construct — it is part of the C
*language*, parsed only by the C compiler proper (`cc1`). That stage never runs
for a `.S` file. Therefore the `*_gc` enum members **do not exist** in the
assembly world, even with `#include <avr/io.h>`.

### The failure mode

```asm
ldi   r16, PORTMUX_USART0_ALT3_gc     ; <-- DON'T: undefined in assembly
sts   PORTMUX_USARTROUTEA, r16
```

GAS treats the unknown name as an **undefined external symbol** (value 0 at
assemble time). You then get either:

- a **link error**: `undefined reference to 'PORTMUX_USART0_ALT3_gc'`, or
- if it resolves to 0, **DEFAULT routing** (the wrong pins) with no diagnostic.

Either way you never get the `3` you wanted.

---

## The correct pattern — build the value from `_gp`

Since `_gp` and `_gm` are real `#define`s, reconstruct the value as
**code shifted into position**:

```asm
#include <avr/io.h>

; Route USART0 to PD4..PD7  ==  PORTMUX_USART0_ALT3_gc, rebuilt by hand.
; ALT3's numeric code is 3 (read it from the _gc enum comment in the header).
ldi   r16, (3 << PORTMUX_USART0_gp)     ; = 0x03
sts   PORTMUX_USARTROUTEA, r16          ; PORTMUX is extended I/O -> sts, not out
```

If the register holds other fields too, do a **read-modify-write** and use the
group mask so you only disturb your field:

```asm
lds   r16, PORTMUX_USARTROUTEA
andi  r16, ~PORTMUX_USART0_gm           ; clear the 3-bit field (mask = 0x07)
ori   r16, (3 << PORTMUX_USART0_gp)     ; OR in ALT3
sts   PORTMUX_USARTROUTEA, r16
```

### Two details that bite people

- **`lds`/`sts`, not `in`/`out`.** `PORTMUX.USARTROUTEA` is at `0x05E2`, far
  outside the low I/O space the `in`/`out` instructions can reach. Most modern
  peripheral registers are in extended I/O — use `lds`/`sts`.
- **Always write `(code << *_gp)`, even when `_gp == 0`.** Here `(3 << 0)` is
  just `3`, so `ldi r16, 0x03` would also work — but the shifted form is
  self-documenting *and* stays correct for fields that are **not** at bit 0
  (e.g. `PORTMUX_EVOUTC_gp == 2`, so its codes land at bits [3:2]).

---

## The reusable recipe (any field, any peripheral)

1. Open [`ioavr64dd32.h`](./ioavr64dd32.md) and find the `*_enum` for your
   field. The `(0xNN<<shift)` gives the **numeric code**; the trailing comment
   gives the **pin mapping**. That is how you learn "ALT3 = 3 = PD4–PD7".
2. Grab the assembler-visible `#define`s for that field:
   `PERIPH_FIELD_gp` (position) and `PERIPH_FIELD_gm` (mask).
3. In assembly, build the value as `(CODE << PERIPH_FIELD_gp)`. Clear first with
   `andi rX, ~PERIPH_FIELD_gm` if the register holds other fields.
4. Use `lds`/`sts` for PORTMUX and most modern-AVR peripheral registers.

### Worked second example — SPI0 pins

```c
/* from ioavr64dd32.h */
PORTMUX_SPI0_DEFAULT_gc = (0x00<<0)   /* PA4, PA5, PA6, PA7 */
PORTMUX_SPI0_ALT3_gc    = (0x03<<0)   /* PA0, PA1, PC0, PC1 */
#define PORTMUX_SPI0_gm  0x07
#define PORTMUX_SPI0_gp  0
```

```asm
; Route SPI0 to PA0, PA1, PC0, PC1  (ALT3, code 3)
ldi   r16, (3 << PORTMUX_SPI0_gp)
sts   PORTMUX_SPIROUTEA, r16
```

---

## Mental model

The header hands C two things for each field: a convenient **pre-shifted enum
value** (`*_gc`) and the raw **position/mask `#define`s** (`*_gp` / `*_gm`).
Assembly only ever gets the `#define`s, so you rebuild the enum value yourself:

```
register value = numeric_code << *_gp
```

See also: [AVR64DD32 header reference](./ioavr64dd32.md),
[Headless debugging with gdb-dashboard](./gdb-dashboard.md).
