; =============================================================
; main  –  Change the system clock freq on the AVR64DD32
; Default : AVR64DD32 @ 4 Mhz
; Target : AVR64DD32 @ 24 Mhz
; Clock defaults to 4Mhz, for a different freq below needs to be called
;    CLKCTRL_FRQSEL_1M_gv           = 0x00,  /* 1 MHz system clock */
;    CLKCTRL_FRQSEL_4M_gv           = 0x03,  /* 4 MHz system clock (default) */
;    CLKCTRL_FRQSEL_8M_gv           = 0x05,  /* 8 MHz system clock */
;    CLKCTRL_FRQSEL_16M_gv          = 0x07,  /* 16 MHz system clock */
;    CLKCTRL_FRQSEL_24M_gv          = 0x09   /* 24 MHz system clock */
; =============================================================

#include <avr/io.h>
#include "registers.S"

.global  set_1M
set_1M:                      ; set clock to 1Mhz
; CLKCTRL_FRQSEL_1M_gc          = (CLKCTRL_FRQSEL_1M_gv << CLKCTRL_FRQSEL_gp)          
    ldi   temp_17, (0x00 << CLKCTRL_FRQSEL_gp)
    rjmp  set_clock

.global  set_4M
set_4M:                      ; set clock to 4Mhz
; CLKCTRL_FRQSEL_4M_gc          = (CLKCTRL_FRQSEL_4M_gv << CLKCTRL_FRQSEL_gp)          
    ldi   temp_17, (0x03 << CLKCTRL_FRQSEL_gp)
    rjmp  set_clock

.global  set_8M
set_8M:                      ; set clock to 8Mhz
; CLKCTRL_FRQSEL_8M_gc          = (CLKCTRL_FRQSEL_8M_gv << CLKCTRL_FRQSEL_gp)          
    ldi   temp_17, (0x05 << CLKCTRL_FRQSEL_gp)
    rjmp  set_clock

.global  set_16M
set_16M:                      ; set clock to 16Mhz
; CLKCTRL_FRQSEL_16M_gc          = (CLKCTRL_FRQSEL_16M_gv << CLKCTRL_FRQSEL_gp)          
    ldi   temp_17, (0x07 << CLKCTRL_FRQSEL_gp)
    rjmp  set_clock

.global  set_24M
set_24M:                      ; set clock to 24Mhz
; CLKCTRL_FRQSEL_24M_gc          = (CLKCTRL_FRQSEL_24M_gv << CLKCTRL_FRQSEL_gp)          
    ldi   temp_17, (0x09 << CLKCTRL_FRQSEL_gp)

set_clock:
; --- Set OSCHF to CLKCTRL_FRQSEL value ---
; CCP_IOREG_gc (CCP_IOREG_gv << CPU_CCP_gp) = (0xD8 << 0) signature for protected I/O
    ldi   temp_16, (0xD8 << 0)
    out   CCP, temp_16                   ; arm CCP (4-cycle window starts)
    sts   CLKCTRL_OSCHFCTRLA, temp_17    ; write within 4 cycles

; --- Disable prescaler: run main clock at desired frequency ---
    ldi   temp_16, (0xD8 << 0)
    ldi   temp_17, 0x00                  ; PEN = 0
    out   CCP, temp_16
    sts   CLKCTRL_MCLKCTRLB, temp_17
    ret

.type   d_100cycles, @function
d_100cycles:                      ; serves as main_setup
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

.section .data
.section .bss
