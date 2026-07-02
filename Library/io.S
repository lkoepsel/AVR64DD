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

.type   bitmask, @function
;------------------------------------------------------------------------------
;  bitmask : r24 = pin number (0..7)  ->  r24 = (1 << pin)
;------------------------------------------------------------------------------
bitmask:
        mov     r25, r24                ; r25 = shift count
        ldi     r24, 1                  ; start mask = 0b00000001
bm_loop:
        tst     r25
        breq    bm_done
        lsl     r24                     ; mask <<= 1
        dec     r25
        rjmp    bm_loop
bm_done:
        ret

.section .data
.section .bss
