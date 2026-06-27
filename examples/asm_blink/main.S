; =============================================================
; main  –  Blink the user LED on PF5 at ~2 Hz (≈250 ms on / 250 ms off)
; Target : AVR64DD32 @ 4 MHz
; Board  : AVR64DD32 Curiosity Nano — LED0 is wired to PF5
; =============================================================

#include <avr/io.h>
#include "registers.S"

; -------------------- Interrupt vector table --------------------
; No interrupts are enabled, only vector 0/RESET can be taken
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler           ; vector 0  RESET

.section .text

.type   reset_handler, @function
reset_handler:                      ; serves as main_setup
    sbi     VPF_DIR, LED            ; PF5 as output

main_loop:
    sbi     VPF_IN, LED             ; toggle PF5
    delay_16   0xfffe
    rjmp    main_loop
.size   reset_handler, .-reset_handler

.section .data
.section .bss
