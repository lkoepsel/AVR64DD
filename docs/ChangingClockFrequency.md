# Changing the Clock Frequency

## **CLKCTRL** peripheral

No fuses or hardware changes required for the main frequency selection.

The main internal high-frequency oscillator (OSCHF) and its prescaler are set in software. Because these are protected registers, you must write them through the Configuration Change Protection (CCP) mechanism using the `ccp_write_io()` helper (or `_PROTECTED_WRITE()` macro).

The two relevant registers:

- **CLKCTRL.OSCHFCTRLA** — selects the internal high-frequency oscillator base frequency (1, 2, 3, 4 MHz and 8, 12, 16, 20, 24 MHz are the selectable values via the `FREQSEL` field).
- **CLKCTRL.MCLKCTRLB** — enables and sets the main clock prescaler (PEN bit + PDIV field: /2, /4, /6, /8, /10, /12, /16, /24, /32, /48, /64).

## Assembly Language example

Here's the CCP sequence in AVR assembly. The protected write requires writing the CCP signature `0xD8` to the CCP register, then writing the target register **within four instruction cycles** (interrupts disabled during the sequence).

```asm
#include <avr/io.h>

; --- Set OSCHF to 24 MHz ---
    ldi   r16, CCP_IOREG_gc          ; 0xD8, signature for protected I/O
    ldi   r17, CLKCTRL_FREQSEL_24M_gc
    out   CCP, r16                   ; arm CCP (4-cycle window starts)
    sts   CLKCTRL_OSCHFCTRLA, r17    ; write within 4 cycles

; --- Disable prescaler: run main clock at full 24 MHz ---
    ldi   r16, CCP_IOREG_gc
    ldi   r17, 0x00                  ; PEN = 0
    out   CCP, r16
    sts   CLKCTRL_MCLKCTRLB, r17
```

Key points:

**CCP is a low I/O register** (address 0x34), so `out`/`in` work on it directly. The CLKCTRL registers live in extended I/O, so they need `sts` (not `out`).

**The 4-cycle window:** after `out CCP, r16`, the CPU sets CCP protection active for the next 4 instruction cycles. Your `sts` must complete within that window. `sts` to extended I/O is 2 cycles, so loading the value into `r17` *before* arming CCP (as above) is essential — don't put an `ldi` between the `out` and the `sts`.

**Disable interrupts** around the sequence if any ISR could fire and disturb timing:

```asm
    in    r18, SREG                  ; save status (preserves I flag)
    cli
    ldi   r16, CCP_IOREG_gc
    ldi   r17, CLKCTRL_FREQSEL_24M_gc
    out   CCP, r16
    sts   CLKCTRL_OSCHFCTRLA, r17
    out   SREG, r18                  ; restore (re-enables I if it was set)
```

**For a prescaler instead** (e.g. 24 MHz / 4 = 6 MHz), the second write becomes:

```asm
    ldi   r17, CLKCTRL_PDIV_4X_gc | CLKCTRL_PEN_bm
```

A couple of things to verify against your header (`grep CCP_ ioavr64dd32.h` and `grep CLKCTRL_ ioavr64dd32.h`):

- `CCP_IOREG_gc` is `0xD8` for protected I/O registers (distinct from `CCP_SPM_gc` = `0x9D` used for self-programming). CLKCTRL uses the I/O signature.
- The `CCP` register itself: in some header versions you reference it bare as `CCP`, in others as `CPU_CCP`. If `out CCP, r16` doesn't assemble, try `out CPU_CCP, r16`.

If you'd rather use the avr-libc helper instead of hand-coding, `<avr/cpufunc.h>` provides `ccp_write_io()` callable from C, but in pure assembly the sequence above is the canonical form.

## Example in C, setting the internal oscillator to 24 MHz with no prescaler:

```c
#include <avr/io.h>

/* Set OSCHF to 24 MHz */
_PROTECTED_WRITE(CLKCTRL.OSCHFCTRLA,
                 CLKCTRL_FREQSEL_24M_gc);

/* Disable prescaler (run main clock at full 24 MHz) */
_PROTECTED_WRITE(CLKCTRL.MCLKCTRLB, 0);
```

To instead run at 24 MHz / 4 = 6 MHz:

```c
_PROTECTED_WRITE(CLKCTRL.MCLKCTRLB,
                 CLKCTRL_PDIV_4X_gc | CLKCTRL_PEN_bm);
```

A few points worth noting for the classroom:

- The default out-of-reset main clock is the internal oscillator running such that CLKCTRL gives an effective **4 MHz** system clock (OSCHF defaults plus the reset prescaler state); students often expect 20 or 24 and are surprised.
- `MCLKCTRLA` selects the *clock source* (internal OSCHF, internal 32 kHz, external 32 kHz crystal, or external clock). For most lab work you leave it on OSCHF.
- The `FREQSEL` field only offers the discrete values above — you can't get arbitrary frequencies from OSCHF, though the prescaler extends the set downward.
- If you want to verify the running frequency empirically, route the main clock to a pin via **CLKCTRL** clock output (the CLKOUT bit in MCLKCTRLA) and measure it.
- In assembly, the same writes apply, but you must hand-roll the CCP sequence: write the CCP signature (`0xD8` for I/O-protected registers) to the `CCP` register, then within four instruction cycles write the target register.

The exact `FREQSEL`, `PDIV`, and bit definitions are in `ioavr64dd32.h` (grep `CLKCTRL_`), and the register descriptions are in datasheet DS40002315A under the CLKCTRL section.