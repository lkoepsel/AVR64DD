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
; CCP_IOREG_gc (CCP_IOREG_gv << CPU_CCP_gp) = (0xD8 << 0) signature for protected I/O
    ldi   temp_16, (0xD8 << 0)
; CLKCTRL_FRQSEL_24M_gc          = (CLKCTRL_FRQSEL_24M_gv << CLKCTRL_FRQSEL_gp)          
    ldi   temp_17, (0x09 << CLKCTRL_FRQSEL_gp)
    out   CCP, temp_16                   ; arm CCP (4-cycle window starts)
    sts   CLKCTRL_OSCHFCTRLA, temp_17    ; write within 4 cycles

; --- Disable prescaler: run main clock at full 24 MHz ---
    ldi   temp_16, (0xD8 << 0)
    ldi   temp_17, 0x00                  ; PEN = 0
    out   CCP, temp_16
    sts   CLKCTRL_MCLKCTRLB, temp_17

.section .data
.section .bss
