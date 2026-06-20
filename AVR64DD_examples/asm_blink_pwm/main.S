; =============================================================
; main  –  Simplest possible hardware PWM with Timer/Counter A (TCA0)
; Target : AVR64DD32 @ 4 MHz   (factory default: internal OSCHF, no prescale)
; Board  : AVR64DD32 Curiosity Nano
; Build  : freestanding (-nostartfiles -nostdlib)
;          file owns the interrupt vector table and the reset/setup code.
;
; OUTPUT PIN:  PA2   <-- probe this with the oscilloscope.
;
; PWM behaviour (datasheet 23.3.3.4, single-slope): the counter counts UP from
; 0 to PER; the output is set HIGH at BOTTOM and cleared LOW on the compare
; match.  Duty(POS) = CMP2 / (PER + 1).
;
;   F_CPU = 4 MHz, prescaler = 1, PER = 255  ->  PWM = 4 MHz / 256 = 15.625 kHz
;   CMP2  = 63                               ->  duty = 63 / 256  = ~25 %
; =============================================================

#include <avr/io.h>
#include "registers.S"

; ---------- Pin / register aliases ----------
; Other definitions in registers.S
; only the example-specific pin numbers here
#define WO2_PIN     2                                   // PA2 == TCA0 WO2
#define WGM_SINGLESLOPE  (0x3 << TCA_SINGLE_WGMODE_gp)  // CTRLB: single-slope PWM

; ---------- PWM parameters ----------
.equ    PER_TOP, 255                    ; TOP -> 256 steps, 15.625 kHz @ 4 MHz
.equ    DC, 70                          ; duty cycle (%)
.equ    CMP_VAL, (DC * (PER_TOP + 1)) / 100   ; compare value for the duty cycle

; -------------------- Interrupt vector table --------------------
; No interrupts, only vector 0 (RESET) is ever taken
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler           ; vector 0  RESET

.section .text

reset_handler:                  
    ; simple init: hardware points SP at RAMEND at reset, no stack req'd

    ; --- PA2 as output for WO2 waveform
    sbi     PORTA_DIR, WO2_PIN

    ; --- TCA0 normal (16-bit) single-slope PWM on WO2 ---
    ; PER and CMP2 are 16-bit; write the low byte then the high byte.
    ldi     temp_16, lo8(PER_TOP)
    sts     TCA0_SINGLE_PERL, temp_16
    ldi     temp_16, hi8(PER_TOP)
    sts     TCA0_SINGLE_PERH, temp_16           ; PER = period (sets PWM frequency)

    ldi     temp_16, lo8(CMP_VAL)
    sts     TCA0_SINGLE_CMP2L, temp_16
    ldi     temp_16, hi8(CMP_VAL)
    sts     TCA0_SINGLE_CMP2H, temp_16          ; CMP2 = duty cycle on WO2

    ldi     temp_16, WGM_SINGLESLOPE | TCA_SINGLE_CMP2EN_bm
    sts     TCA0_SINGLE_CTRLB, temp_16          ; single-slope PWM, enable WO2 output

    ldi     temp_16, TCA_SINGLE_ENABLE_bm       ; CLKSEL = DIV1 (0), ENABLE = 1
    sts     TCA0_SINGLE_CTRLA, temp_16          ; start the timer

main_loop:
    rjmp    main_loop               ; PWM runs autonomously in hardware

.section .data
.section .bss
