; =============================================================
; main  –  Blink LED to demonstrate clock freq change
;          Best measured with a scope
; Target : AVR64DD32 @ 4 MHz (default)
; Board  : AVR64DD32 Curiosity Nano
; =============================================================

#include <avr/io.h>
#include "registers.S"
#include "clocks.S"

; -------------------- Interrupt vector table --------------------
; No interrupts are enabled, only vector 0/RESET can be taken
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler           ; vector 0  RESET

.section .text

.type   reset_handler, @function
reset_handler:                      ; serves as main_setup
    sbi     VPF_DIR, LED            ; LED as output

main_loop:
    sbi     VPF_IN, LED             ; toggle LED
    rcall   d_100cycles
    rjmp    main_loop
.size   reset_handler, .-reset_handler

; ---- busy-wait delay, ~25 us at 4 MHz (≈100 cycles) ----
; Simple dec/brne loop, inner iteration is 93 cycles
; Call overhead is 10 cycles
;Per toggle: 1 + 3 + 93 + 4 + 2 = 103 cycles → 103 × 0.25 µs = 25.75 µs.
.type   d_100cycles, @function
d_100cycles:
    ldi  temp_20, 31     ; 1 cycle, runs once
d_outer:
    dec  temp_20         ; 1 cycle
    brne d_outer         ; 2 cycles when it branches, 1 when it falls through
    ret                  ; 4 cycles (AVR-Dx, see note).size   delay_250ms, .-delay_250ms

.section .data
.section .bss
