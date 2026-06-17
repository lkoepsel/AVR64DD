; =============================================================
; main  –  Blink the user LED on PF5 at ~2 Hz (≈250 ms on / 250 ms off)
; Target : AVR64DD32 @ 4 MHz   (factory default: internal OSCHF, no prescale)
; Board  : AVR64DD32 Curiosity Nano — LED0 is wired to PF5
; Build  : freestanding (-nostartfiles -nostdlib). This file owns the
;          interrupt vector table and the reset/setup code; there is no
;          C runtime to do it for us.
;
; Modern-AVR (AVR-Dx) notes vs. the classic ATtiny13A:
;   * Ports are reached through VPORTx registers (DIR/OUT/IN/INTFLAGS).
;     VPORTA..VPORTH sit in the low I/O space (0x00–0x1F), so the
;     single-cycle bit ops sbi/cbi/sbic/sbis work on them directly.
;   * Writing a 1 to a VPORTx.IN bit TOGGLES the matching OUT bit —
;     the modern equivalent of the ATtiny "write 1 to PINx" trick.
;   * The stack pointer is 16-bit (SPH:SPL) and is already initialised
;     to RAMEND by hardware at reset; we set it explicitly anyway so the
;     intent is obvious.
; =============================================================

#include <avr/io.h>

; ---------- Pin / register aliases ----------
; NOTE: comments on #define lines must use C-style // (or /* */), not ';'.
; The preprocessor would fold a ';' comment into the macro body, and when the
; alias is used as sbi's first operand it would comment out the bit number.
#define LED         5                          // PF5 == LED0 on the Nano
#define VPORT_DIR   _SFR_IO_ADDR(VPORTF_DIR)   // PORTF data-direction  (0x14)
#define VPORT_IN    _SFR_IO_ADDR(VPORTF_IN)    // write 1 -> toggle OUT (0x16)
#define STACK_LOW   _SFR_IO_ADDR(SPL)
#define STACK_HIGH  _SFR_IO_ADDR(SPH)
#define STATUS      _SFR_IO_ADDR(SREG)

; -------------------- Interrupt vector table --------------------
; On a >8 KB-flash AVR-Dx each vector entry is a 2-word JMP. We never
; enable interrupts (the global I-bit stays clear after reset), so only
; vector 0 — RESET — is ever taken. The linker places .vectors at 0x0000.
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler           ; vector 0  RESET

.section .text

reset_handler:                      ; also serves as main_setup
    ldi     r16, hi8(RAMEND)        ; init 16-bit stack pointer
    out     STACK_HIGH, r16
    ldi     r16, lo8(RAMEND)
    out     STACK_LOW, r16
    eor     r1, r1                  ; r1 = GCC __zero_reg__ convention
    out     STATUS, r1              ; clear status register

    sbi     VPORT_DIR, LED          ; PF5 as output

main_loop:
    sbi     VPORT_IN, LED           ; toggle PF5 (write 1 to VPORTF.IN)
    rcall   delay_250ms
    rjmp    main_loop

; ---- busy-wait delay, ~250 ms at 4 MHz (≈1,000,000 cycles) ----
; Triple-nested dec/brne. Inner iteration is 3 cycles; the constants
; below give 21 × 250 × 64 × 3 ≈ 1,008,000 cycles ≈ 252 ms. Approximate
; — fine for a visible blink; use a timer for precise timing.
delay_250ms:
    ldi     r18, 21
d_outer:
    ldi     r19, 250
d_mid:
    ldi     r20, 64
d_inner:
    dec     r20
    brne    d_inner
    dec     r19
    brne    d_mid
    dec     r18
    brne    d_outer
    ret

.section .data
.section .bss
