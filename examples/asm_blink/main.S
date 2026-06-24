; =============================================================
; main  –  Blink the user LED on PF5 at ~2 Hz (≈250 ms on / 250 ms off)
; Target : AVR64DD32 @ 4 MHz
; Board  : AVR64DD32 Curiosity Nano — LED0 is wired to PF5
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
    sbi     VPF_DIR, LED            ; PF5 as output
    ; rcall   set_24M               ; call to set clock to 24Mhz

main_loop:
    sbi     VPF_IN, LED             ; toggle PF5
    rcall   delay_250ms
    rjmp    main_loop
.size   reset_handler, .-reset_handler

; ---- busy-wait delay, ~250 ms at 4 MHz (≈1,000,000 cycles) ----
; Triple-nested dec/brne. Inner iteration is 3 cycles; the constants
; below give 21 × 250 × 64 × 3 ≈ 1,008,000 cycles ≈ 252 ms. 
.type   delay_250ms, @function
delay_250ms:
    ldi     temp_20, 21
d_outer:
    ldi     temp_21, 250
d_mid:
    ldi     temp_22, 64
d_inner:
    dec     temp_22
    brne    d_inner
    dec     temp_21
    brne    d_mid
    dec     temp_20
    brne    d_outer
    ret
.size   delay_250ms, .-delay_250ms

.section .data
.section .bss
