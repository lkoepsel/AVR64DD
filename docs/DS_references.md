# Explanation of References (Claude)

## `TCA_SINGLE_WGMODE_gp` breaks into four parts:

1. **TCA** — the peripheral: the Timer/Counter type A.

2. **SINGLE** — the operating mode/configuration of the peripheral. TCA can run in either SINGLE mode (one 16-bit timer) or SPLIT mode (two independent 8-bit timers); this symbol applies to the SINGLE-mode register layout.

3. **WGMODE** — the specific bitfield: the Waveform Generation Mode bits in the CTRLB register, which select the timer's mode of operation (NORMAL, FRQ, single-slope PWM, dual-slope PWM variants).

4. **_gp** — the suffix meaning **group position**: the starting bit position (the index of the field's least-significant bit) of the WGMODE field within the register. It's a plain integer, distinct from the companion `_gm` (group mask) and `_gc` (group configuration enum values).

So the full reference is the bit position of the Waveform Generation Mode field in the single-mode Timer/Counter A.

## `TCA_SINGLE_WGMODE_gp` is a macro:

Which is defined in the device-specific I/O header that ships with the AVR toolchain (avr-libc / the AVR-Dx device pack), not in a Microchip datasheet. The datasheet documents the register and bitfield (WGMODE in TCA.SINGLE.CTRLB); the `_gp`/`_gm`/`_gc` macros are the toolchain's encoding of that.

Specifically, look in:

`ioavr64dd32.h` — the device header, included via `<avr/io.h>` when `__AVR_AVR64DD32__` is defined.

Typical locations depending on how your toolchain is installed:

- System avr-gcc (Linux/CachyOS): `/usr/avr/include/avr/ioavr64dd32.h` or `/usr/lib/avr/include/avr/ioavr64dd32.h`
- Microchip XC8/AVR-Dx pack: under the pack's `include/avr/` directory

You can locate it directly:

```
find / -name 'ioavr64dd32.h' 2>/dev/null
```

Inside, search for the field and you'll find the trio:

```
grep TCA_SINGLE_WGMODE ioavr64dd32.h
```

which yields something like:

```c
#define TCA_SINGLE_WGMODE_gm  0x07  /* Waveform generation mode group mask */
#define TCA_SINGLE_WGMODE_gp  0     /* Waveform generation mode group position */
#define TCA_SINGLE_WGMODE_0_bm  ...
...
#define TCA_SINGLE_WGMODE_NORMAL_gc (0x00<<0)  /* Normal Mode */
#define TCA_SINGLE_WGMODE_FRQ_gc    (0x01<<0)  /* Frequency Generation Mode */
#define TCA_SINGLE_WGMODE_SINGLESLOPE_gc (0x03<<0)
...
```

Note the pattern: `_gc` values are already shifted by `_gp`, so you typically assign a `_gc` directly (`TCA0.SINGLE.CTRLB = TCA_SINGLE_WGMODE_SINGLESLOPE_gc;`) rather than using `_gp` manually.

If you can't find the header on disk, the same definitions live in Microchip's Atmel-packs (the AVR-Dx DFP), which you can browse or unzip from the `.atpack` file.


## Header-defined macros

For a multi-bit bitfield (a "group") like WGMODE, the header defines three related macros:

- **`_gp` (group position)** — a plain integer giving the bit index of the field's least-significant bit within the register. For `TCA_SINGLE_WGMODE_gp` that's `0`, since WGMODE occupies bits 0–2 of CTRLB.

- **`_gm` (group mask)** — the bitmask covering the whole field, already in place. For WGMODE that's `0x07` (bits 0,1,2 set).

- **`_gc` (group configuration)** — the set of named enum-style values for the field, each *already shifted* into position by `_gp`. E.g. `TCA_SINGLE_WGMODE_SINGLESLOPE_gc` is `(0x03 << 0)`.

The relationship: `_gc value == (raw_value << _gp)`, and `_gm == (max_raw_value << _gp)`.

The practical consequence is that you rarely use `_gp` directly when a `_gc` exists — you just assign the `_gc`. `_gp` becomes useful when you're computing a field value at runtime (no predefined `_gc`), e.g. shifting a variable into position:

```c
TCA0.SINGLE.CTRLB = (TCA0.SINGLE.CTRLB & ~TCA_SINGLE_WGMODE_gm)
                  | (mode << TCA_SINGLE_WGMODE_gp);
```
