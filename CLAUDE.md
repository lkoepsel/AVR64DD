# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A collection of bare-metal AVR example programs — C (AVR-LibC, C99) and AVR
assembly — targeting the **AVR64DD32** (Curiosity Nano board) with a
set of examples. There is no application; each example directory is an independent, flashable firmware. The value is in the
shared build system and the hand-written assembly library, not in any single
program.

## Build & flash

Each example is built from *inside its own directory*. You don't build from the
repo root.

```sh
cd AVR64DD_examples/asm_blink   # or any example dir
make            # = make all: compile + link -> main.hex
make compile    # build main.hex only
make flash      # build, print size, upload to board via avrdude
make size       # report flash/RAM usage of main.elf
make disasm     # produce main.lst (annotated disassembly)
make clean      # remove build artifacts in this dir
make complete   # all_clean + compile + size (full rebuild)
make verbose    # like flash, with full avrdude programming output
make env        # print the active env.make variables (MCU, F_CPU, programmer…)
make help       # list targets
```

Static analysis (from a dir containing `test.cppcheck`/`suppressions.txt`, i.e.
the repo root): `make static` runs cppcheck for `--platform=avr8` into
`cppcheck.txt`.

There is **no test suite** — verification is "does it build and run on the
chip." The closest thing to CI is `make build_all` (clean + build every
example, report failures) and `make clean_all`. ⚠️ Both targets glob
`$(DEPTH)examples/*/`, but the actual example directory is only examples/`, so it currently matches nothing
— treat these targets as stale until the path is fixed.

## How the build system fits together

The architecture that needs multiple files to understand:

- **One root `Makefile`, many thin wrappers.** Every example's local `Makefile`
  is two lines: `DEPTH = ../../` then `include $(DEPTH)Makefile`. All real build
  logic lives in the root `Makefile`. A local Makefile only adds per-example
  overrides — most commonly `ASM_LIBS = $(LIBDIR)/serial.S` to pull in a shared
  assembly source, or a `FREESTANDING`/`TARGET` override.

- **`env.make` holds the per-machine, per-board knobs** (`MCU`, `F_CPU`,
  `USB_BAUD`, `SERIAL`, `PROGRAMMER_TYPE`, `PROGRAMMER_ARGS`). It is **git-
  ignored** and must exist at the repo root for any build to work. `env.dev` is
  the tracked template to copy from; it has commented-out blocks for switching
  targets/programmers — uncomment the one you're building for. Device support
  (specs, io headers, libs) comes from a modern avr-gcc/avr-libc that knows the
  AVR-Dx parts; there is no in-repo device pack.

- **Freestanding vs. C-runtime linking is auto-detected.** If an example has no
  `.c` sources (assembly-only), the Makefile sets `FREESTANDING=1` and links
  with `-nostartfiles -nostdlib`: the example's own `main.S` provides the
  `.vectors` interrupt table and the reset handler. Any `.c` source switches to
  a normal C-runtime link (with `--gc-sections`, a `.map` file, etc.). This is
  why a single Makefile builds pure-asm, pure-C, and mixed examples without
  configuration.

- **Naming convention:** assembly examples are prefixed `asm_` and use `main.S`
  (uppercase `.S` so the C preprocessor runs first, enabling `#include
  <avr/io.h>` and `_SFR_IO_ADDR(...)`). C / mixed examples use `main.c`.

## The shared assembly library (`Library/`)

Hand-written `.S` routines meant to be called from C, each paired with a C
header declaring the ABI: `serial.S`/`serial_asm.h`, `sysclock.S`/
`sysclock_asm.h`, `eeprom.S`/`eeprom_asm.h`, plus `registers.S`. To use one,
list its `.S` in the example's `ASM_LIBS` and include the header.

Two cross-cutting constraints you must respect:

- **r8 and r9 are reserved globally.** The root Makefile compiles all C with
  `-ffixed-r8 -ffixed-r9` because the assembly `sysclock` tick counter lives in
  that register pair. Don't write C or asm that clobbers r8:r9.
- **Calling convention is the AVR-GCC ABI**, documented per-function in the
  `*_asm.h` headers: byte args/returns in `r24`, words in `r25:r24`, a flash
  address in `r31:r30` (Z). Match these exactly when adding routines.

## Debugging (Bloom + avr-gdb)

Debugging uses [Bloom](https://bloom.oscillate.io/) as the GDB server bridge to
the hardware (the recommended workflow on Linux). `bloom.yaml` configures it:
`curiosity_nano` tool, `avr64dd32` target over UPDI, GDB RSP server on
`127.0.0.1:1442`. `bloom.yaml` is git-ignored (a template is committed). For
debugWIRE-style ATtiny targets, prefer gdb `load` + `mon reset` over re-flashing
with avrdude to avoid churning the DWEN fuse (see README).

## Reference material

The `documentation/` folder holds local PDFs (AVR64DD datasheet, instruction
set, avr-libc manual, gcc/gdb/as manuals, Curiosity Nano user guide). The README
is extensive — for AVR64DD
specifics, prefer the in-tree `AVR64DD_examples/` sources and `bloom.yaml`.
