; =============================================================
; main  –  Change the system clock freq on the AVR64DD32
; Target : AVR64DD32 @ 4 MHz
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

; --- Set OSCHF to 24 MHz ---
    ldi   r16, CCP_IOREG_gc          ; 0xD8, signature for protected I/O
    ldi   r17, CLKCTRL_FREQSEL_24M_gc
    out   CCP, r16                   ; arm CCP (4-cycle window starts)
    sts   CLKCTRL_OSCHFCTRLA, r17    ; write within 4 cycles

; --- Disable prescaler: run main clock at full 24 MHz ---
    ldi   r16, CCP_IOREG_gc
    ldi   r17, 0x00                  ; PEN = 0
    out   CCP, r16
    sts   CLKCTRL_MCLKCTRLB, r17

.section .data
.section .bss
