; =============================================================
; main  –  Change the system clock freq on the AVR64DD32
; Default : AVR64DD32 @ 4 Mhz
; Target : AVR64DD32 @ 24 Mhz
; Clock is dynamic, so set_24M needs to be called for 24MHz
;    CLKCTRL_FRQSEL_1M_gv           = 0x00,  /* 1 MHz system clock */
;    CLKCTRL_FRQSEL_4M_gv           = 0x03,  /* 4 MHz system clock (default) */
;    CLKCTRL_FRQSEL_8M_gv           = 0x05,  /* 8 MHz system clock */
;    CLKCTRL_FRQSEL_16M_gv          = 0x07,  /* 16 MHz system clock */
;    CLKCTRL_FRQSEL_24M_gv          = 0x09   /* 24 MHz system clock */
; =============================================================

#include <avr/io.h>
#include "registers.S"

.global  set_24M
set_24M:                      ; set clock to 24Mhz

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
    ret

.section .data
.section .bss
