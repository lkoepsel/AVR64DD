; =============================================================
; main  –  Toggle LED(PF5) to demonstrate clock freq change
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
reset_handler:
    rcall   set_24M         ; set clock frequency
    rjmp    d_100cycles     ; toggle LED pin at 100 cycles

.section .data
.section .bss
