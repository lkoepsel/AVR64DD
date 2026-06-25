; =============================================================
; main  –  Blink PA2 to demonstrate clock freq change
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
    sbi     VPA_DIR, PA2            ; PA2 as output

main_loop:
    sbi     VPF_IN, PA2             ; toggle PA2
    rcall   delay_250ms
    rjmp    main_loop
.size   reset_handler, .-reset_handler

; ---- busy-wait delay, ~250 us at 4 MHz (≈100 cycles) ----
; Triple-nested dec/brne. Inner iteration is 3 cycles; the constants
; below give 33 × 3 ≈ 100 cycles ≈ 252 us 
.type   delay_250ms, @function
delay_250ms:
    ldi     temp_20, 33
d_outer:
    dec     temp_20
    brne    d_outer
    ret
.size   delay_250ms, .-delay_250ms

.section .data
.section .bss
