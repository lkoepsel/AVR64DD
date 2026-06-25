; =============================================================
; main  –  Blink LED to demonstrate clock freq change
;          Best measured with a scope
; Target : AVR64DD32 @ 4 MHz (default) 100 cycles => 25us
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
    sbi     VPF_IN, LED  ; toggle LED

; ---- busy-wait delay, ~25us at 4 MHz (≈100 cycles) ----
    nop
    ldi  temp_20, 32     ; 1 cycle, runs once
delay_100:
    dec  temp_20         ; 1 cycle
    brne delay_100       ; 2 cycles when it branches, 1 when it falls through
    rjmp    main_loop

.size   reset_handler, .-reset_handler

.section .data
.section .bss
