; =============================================================
; main  –  Blink LED to demonstrate clock freq change
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
    rcall   delay_250ms
    rjmp    main_loop
.size   reset_handler, .-reset_handler

; ---- busy-wait delay, ~25 us at 4 MHz (≈100 cycles) ----
; Simple dec/brne. Inner iteration is 3 cycles; the constants
; below give 31 × 3 ≈ 93 cycles ≈ 25.5us 
.type   delay_250ms, @function
delay_250ms:
    ldi     temp_20, 31
d_outer:
    dec     temp_20
    brne    d_outer
    ret
.size   delay_250ms, .-delay_250ms

.section .data
.section .bss
