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
cd examples/blink   # or any example dir
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
example, report failures) and `make clean_all`. Both targets glob
`$(DEPTH)examples/*/`, which matches the example directories under `examples/`.

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

- **Naming convention:** assembly examples use `main.S` (uppercase `.S` so the
  C preprocessor runs first, enabling `#include <avr/io.h>` and
  `_SFR_IO_ADDR(...)`); C / mixed examples use `main.c`. Example directories are
  plain names under `examples/` (`blink`, `blink_pwm`, `ring`, …) — an older
  `asm_` prefix still appears in some docs but is no longer used.

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

## Debugging (two GDB servers, chosen by platform)

The front end is always `avr-gdb` + [gdb-dashboard](./docs/gdb-dashboard.md) —
modules in `docs/dashboard/` (installed to `~/.gdbinit.d/`), per-example register
/ peripheral / SRAM choices in each example's `avr_dashboard.py`. Only the GDB
*server* differs by platform.

**Linux — Bloom** (unchanged; still the recommended Linux workflow).
[Bloom](https://bloom.oscillate.io/) bridges to the hardware. `bloom.yaml`
configures it: `curiosity_nano` tool, `avr64dd32` target over UPDI, GDB RSP
server on `127.0.0.1:1442`. `bloom.yaml` is git-ignored; copy the YAML block in
`docs/gdb-dashboard.md` to create it.

**macOS — PyAvrOCD.** Bloom is Linux-only (epoll, eventfd, `/proc/self/exe`,
udev rules), so macOS uses [PyAvrOCD](https://pyavrocd.io/), a cross-platform
AVR GDB server supporting debugWIRE / JTAG / UPDI. Default port **2000**.

```sh
pipx install pyavrocd                              # the GDB server
brew tap osx-cross/avr && brew install avr-gdb     # see caveat below

pyavrocd -d avr64dd32 -t nedbg -i updi -F 4000000  # terminal 1
cd examples/blink && avr-gdb                       # terminal 2 (auto-connects)
```

⚠️ **avr-gdb must be built with Python support** — gdb-dashboard is a Python
script. PyAvrOCD ships prebuilt macOS `avr-gdb` binaries, but they are built
*without* Python and the dashboard will not run on them. The `osx-cross/avr`
tap's build does have it (verified: GDB 17.2, Python 3.14.7). Installing that
formula does **not** pull in avr-gcc — `avr-gcc@15` is a `=> :test` dependency —
so a hand-built `/usr/local/avr` toolchain is left untouched. Homebrew needs
`brew trust osx-cross/avr` before it will install from the tap.

The installed `~/.gdbinit.d/avr_connect.gdb` differs from the repo copy in one
way: `connect` tries `:2000` (PyAvrOCD) then `:1442` (Bloom), so the same
command works on both platforms. `connect 1442` forces a specific port.

> **C-only caveat:** avr-gcc 15.1 emits buggy debug info for *local variables*
> (noted in PyAvrOCD's docs; the `osx-cross/avr` tap ships 15.2.0). Assembly
> examples are unaffected — they have no C locals.

For debugWIRE-style ATtiny targets, prefer gdb `load` + `mon reset` over
re-flashing with avrdude to avoid churning the DWEN fuse (see README).

## Reference material

The `documentation/` folder holds local PDFs (AVR64DD datasheet, instruction
set, avr-libc manual, gcc/gdb/as manuals, Curiosity Nano user guide). The README
is extensive — for AVR64DD specifics, prefer the in-tree `examples/` sources.
