Right — `SBI`/`CBI` encode the bit number *in the opcode*, so the bit must be a compile-time constant. You can't feed them a pin number from a register. This is exactly the wall you hit when the pin lives in a struct field.

The standard AVR solution is a **bit mask in a register** plus a read-modify-write, instead of `SBI`/`CBI`:

```asm
; set:   PORTA.OUT |=  (1 << pin)
; clear: PORTA.OUT &= ~(1 << pin)
```

The piece that makes this work is building `(1 << pin)` at runtime from the pin number. AVR has no variable-distance shift, so you loop:

```asm
;------------------------------------------------------------------------------
;  bitmask : r24 = pin number (0..7)  ->  r24 = (1 << pin)
;------------------------------------------------------------------------------
bitmask:
        mov     r25, r24                ; r25 = shift count
        ldi     r24, 1                  ; start mask = 0b00000001
bm_loop:
        tst     r25
        breq    bm_done
        lsl     r24                     ; mask <<= 1
        dec     r25
        rjmp    bm_loop
bm_done:
        ret
```

Then set or clear on PORTA:

```asm
; --- set pin high:  PORTA.OUT |= mask ---
        ; r24 already = mask from bitmask
        lds     r18, PORTA + 0x04       ; PORTA.OUT  (offset 0x04 on this part)
        or      r18, r24
        sts     PORTA + 0x04, r18

; --- set pin low:   PORTA.OUT &= ~mask ---
        com     r24                     ; r24 = ~mask
        lds     r18, PORTA + 0x04
        and     r18, r24
        sts     PORTA + 0x04, r18
```

A cleaner option specific to the DD/modern AVR-Dx: the new PORT peripheral has dedicated **OUTSET** and **OUTCLR** registers, so you don't even need the read-modify-write — just write the mask:

```asm
#define PORTA_SET   _SFR_IO_ADDR(PORTA_OUTSET) // PORTA OUTSET  (VPORT, I/O 0x05)
#define PORTA_CLR   _SFR_IO_ADDR(PORTA_OUTCLR) // PORTA OUTCLR  (VPORT, I/O 0x06)

; set pin high  -> write mask to PORTA.OUTSET
        sts     PORTA_SET, r24       ; OUTSET: 1-bits set the pin

; set pin low   -> write mask to PORTA.OUTCLR
        sts     PORTA_CLR, r24       ; OUTCLR: 1-bits clear the pin
```

OUTSET/OUTCLR are atomic single-write operations — writing a 1 to a bit position sets (or clears) only that pin and ignores the 0 bits, so the other two LEDs are untouched. This is the modern-AVR idiom and it's *better* than the classic SBI/CBI approach for exactly your case: the affected pin is selected by the data you write, not by the opcode.

So the full path for "set the pin in this task's PIN field high" becomes:

```asm
        ldd     r24, Y+PIN              ; r24 = pin number (2, 3, or 4)
        rcall   bitmask                 ; r24 = (1 << pin)
        sts     PORTA_SET, r24       ; PORTA.OUTSET — turn it on
```

and for low, the same but `PORTA_CLR` (OUTCLR).

Use the `io.h` symbols rather than literal offsets so it reads cleanly — with `#include <avr/io.h>` you can write `_SFR_MEM_ADDR(PORTA_OUTSET)` and `_SFR_MEM_ADDR(PORTA_OUTCLR)`, or just `lds`/`sts` against `PORTA_OUTSET` if you let the assembler resolve the struct.