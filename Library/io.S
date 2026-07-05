; =============================================================
; main  –  Change the system clock freq on the AVR64DD32
; Default : AVR64DD32 @ 4 Mhz
; Target : AVR64DD32 @ 24 Mhz
; Clock defaults to 4Mhz, for a different freq below needs to be called
;    CLKCTRL_FRQSEL_1M_gv           = 0x00,  /* 1 MHz system clock */
;    CLKCTRL_FRQSEL_4M_gv           = 0x03,  /* 4 MHz system clock (default) */
;    CLKCTRL_FRQSEL_8M_gv           = 0x05,  /* 8 MHz system clock */
;    CLKCTRL_FRQSEL_16M_gv          = 0x07,  /* 16 MHz system clock */
;    CLKCTRL_FRQSEL_24M_gv          = 0x09   /* 24 MHz system clock */
; =============================================================

#include <avr/io.h>
#include "registers.S"

; Emit into .text explicitly: this file is #included after others whose
; trailing `.section .data/.bss` would otherwise leave bitmask in RAM, so a
; `call bitmask` jumps into data space. (Matches sysclock.S's own .text.)
.section .text

.type   bitmask, @function
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

.type   bad_interrupt, @function
;------------------------------------------------------------------------------
;  bad_interrupt : trap for every unused / unexpected interrupt vector.
;    All vectors except RESET(0) and TCA0_OVF(9) jump here instead of to
;    _start, so a stray interrupt parks the CPU here rather than masquerading
;    as a RESET. It blinks the onboard LED (PF5 / LED0) at ~1 Hz so the trap is
;    obvious with no debugger attached; the steady ~1 Hz flash cannot be
;    confused with the PA2/3/4 task pins or a normal reset.
;      * LED blinking / breakpoint hits -> an unused vector really is firing;
;        read the top of stack (pushed return addr) to see which one.
;      * LED dark / breakpoint never hits -> the "reset" is NOT a stray IRQ.
;    No reti / return: we want it to stay here, not resume.
;    Clobbers r18/r19 (delay_16) and r20 — fine, this never returns.
;------------------------------------------------------------------------------
bad_interrupt:
        sbi     VPF_DIR, LED            ; PF5 (LED0) as output
bad_spin:
        sbi     VPF_IN, LED             ; toggle PF5 (VPORT write-1-to-toggle)
        ldi     temp_20, 8              ; ~8 x 65 ms => ~0.5 s per toggle (~1 Hz)
bad_wait:
        delay_16 0                      ; 0 => 65536 ticks (~65 ms @ 4 MHz)
        dec     temp_20
        brne    bad_wait
        rjmp    bad_spin


.section .data
.section .bss
