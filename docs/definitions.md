In the GNU assembler (avr-as) world, these three all create symbolic constants, but they live in different layers of the toolchain and behave differently in subtle ways.

## `.equ` and `.set` — assembler directives

These are processed by **avr-as itself**, and in GAS they are essentially synonyms:

```asm
.equ    LED_PIN, 5
.set    LED_PIN, 5      ; identical effect
```

Both define an assembler *symbol* with a value. Key properties:

**Redefinition is allowed.** Both `.set` and `.equ` let you reassign the symbol later in the file, and the value used at each point is the value in effect at that line. This makes them useful for things like location counters or computed offsets that change as assembly proceeds:

```asm
.set    offset, 0
lds     r16, task_block + offset
.set    offset, offset + 2
lds     r17, task_block + offset
```

This is handy for your struct-like task block layouts — you can build field offsets incrementally.

**They understand expressions and symbols.** Since the assembler evaluates them, they can reference other symbols, labels, and arithmetic the preprocessor knows nothing about:

```asm
.equ    TASK_SIZE, task_end - task_start
```

**They exist in the symbol table.** Symbols defined this way can show up in the object file (visible to `avr-nm`, and to gdb if made global), which can be nice for debugging. A `#define` leaves no trace after preprocessing.

If you want a "define once, error if redefined" behavior, GAS also offers `.equiv`, which is like `.equ` but complains if the symbol already exists — a nice teaching tool for catching accidental redefinition.

## `#define` — C preprocessor macro

This only works if the file goes through the **C preprocessor**, which means the file must be named `.S` (capital) or you must invoke `avr-gcc` rather than `avr-as` directly. A lowercase `.s` file compiled with avr-gcc skips cpp, and `#define` becomes a syntax error.

```asm
#define LED_PIN 5
```

Properties:

**Pure textual substitution.** The assembler never sees `LED_PIN`; it sees `5`. No symbol table entry, no expression evaluation by the assembler at definition time, no redefinition semantics beyond `#undef`.

**It's what the AVR headers use.** This is the practical reason `#define` matters in AVR work: `<avr/io.h>` and the device headers (`ioavr64dd32.h` etc.) are built entirely from `#define` and C structs. When you write:

```asm
#include <avr/io.h>
ldi     r16, TCB_CLKSEL_CLKDIV1_gc
sts     TCB0_CTRLA, r16
```

all those `_gc`/`_gm`/`_bp` names arrive via the preprocessor. So any assembly file that wants the official register and bitfield names must be a `.S` file processed by avr-gcc — which is presumably how your `sysclock_dd32.S` and `serial_dd32.S` already work.

**Function-like macros.** `#define` supports parameterized macros (`#define low(x) ((x) & 0xFF)`), which `.equ`/`.set` cannot do — the GAS equivalent for that is `.macro`/`.endm`, a different mechanism entirely.

**Conditional assembly.** `#ifdef`, `#if`, `#include` come along with the preprocessor, letting one source file target multiple devices — again exactly how avr-libc's headers select the right definitions from `-mmcu=avr64dd32`.

## Practical summary for the classroom

| | `.equ` / `.set` | `#define` |
|---|---|---|
| Processed by | assembler (avr-as) | C preprocessor (cpp) |
| Works in `.s` files | yes | no (needs `.S` or explicit cpp) |
| Redefinable | yes (both) | only via `#undef` |
| Evaluates assembler expressions/labels | yes | no (text only) |
| Parameterized | no (use `.macro`) | yes |
| Needed for `<avr/io.h>` names | — | yes |

A reasonable house convention: use `#include <avr/io.h>` plus `#define` (or just the header's names) for anything hardware-related, and use `.equ` for program-internal constants and computed offsets where assembler expression evaluation or intentional redefinition is useful. One caveat worth telling students: because both layers are active in a `.S` file, a `#define` can silently rewrite the name in a later `.equ` line — so keep naming conventions distinct (e.g., the headers own ALL_CAPS peripheral names; use a prefix like `k_` or lowercase for your own `.equ` constants).