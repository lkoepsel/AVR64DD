; ====================================================================
;  main_dd32  -  demo driver for sysclock_dd32
;  Target : AVR64DD32 (Curiosity Nano)
;  Toolchain: avr-as / avr-ld  (GNU Binutils for AVR)
;
;  Pure-asm build: we hand-roll the vector table (Option B). The table
;  lives at flash address 0x0000; slot 9 routes TCA0 OVF to our handler.
;
;  If instead you link with avr-gcc and the standard CRT (Option A), you
;  do NOT need this table at all -- the CRT's prebuilt weak table already
;  routes __vector_9 to the handler. In that case main is just the loop.
; ====================================================================

#include <avr/io.h>

; --------------------------------------------------------------------
;  Vector table at 0x0000.  Each slot is a 2-byte rjmp.
;  Only RESET (0) and TCA0_OVF (9) are wired; the rest trap.
; --------------------------------------------------------------------
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    rjmp  reset             ; 0  RESET
    rjmp  __bad_interrupt   ; 1
    rjmp  __bad_interrupt   ; 2
    rjmp  __bad_interrupt   ; 3
    rjmp  __bad_interrupt   ; 4
    rjmp  __bad_interrupt   ; 5
    rjmp  __bad_interrupt   ; 6
    rjmp  __bad_interrupt   ; 7
    rjmp  __bad_interrupt   ; 8
    rjmp  TCA0_OVF_handler  ; 9  TCA0 OVF  (byte address 0x12)
    ; Remaining vectors omitted -- add slots only as you enable more
    ; interrupts. An out-of-range vector simply isn't reachable here.

; --------------------------------------------------------------------
;  Unexpected-interrupt trap. For teaching, spin in place so a stray
;  interrupt is visible under the debugger (PC parks here) rather than
;  silently resetting.
; --------------------------------------------------------------------
.section .text
.global __bad_interrupt
__bad_interrupt:
    rjmp  __bad_interrupt

; --------------------------------------------------------------------
;  Reset / program entry.
; --------------------------------------------------------------------
.global reset
reset:
    ; --- set up the stack pointer to top of SRAM ---
    ;     RAMEND is provided by <avr/io.h> for the AVR64DD32.
    ldi     r16, lo8(RAMEND)
    out     CPU_SPL, r16
    ldi     r16, hi8(RAMEND)
    out     CPU_SPH, r16

    ; --- start the 1 ms system clock (sets up TCA0, enables OVF, sei) ---
    rcall   init_sysclock_1k

main_loop:
    ; --- demo: read the live tick count into r25:r24 ---
    ;     Set a breakpoint here and watch r24/r25 climb ~1000/sec, or
    ;     watch TCA0.CNT in the gdb-dashboard AvrPeripheral module.
    rcall   ticks
    ; (r25:r24 now holds the 16-bit tick count; use as you like)
    rjmp    main_loop
