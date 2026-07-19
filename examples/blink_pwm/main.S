; =============================================================
; main  –  Simple, hardware, pulse-width modulation (PWM)
;          on Timer/Counter A (TCA0), signal is 61Hz, with variable duty cyle
; Target : AVR64DD32 @ 4 MHz   (factory default: internal OSCHF, no prescale)
; Board  : AVR64DD32 Curiosity Nano
; Build  : freestanding (-nostartfiles -nostdlib)
;          file owns the interrupt vector table and the reset/setup code.
;
; OUTPUT PIN:  PA2   <-- probe this with the oscilloscope.
;
; PWM behaviour (datasheet 23.3.3.4, single-slope): the counter counts UP from
; 0 to PER; the output is set HIGH at BOTTOM and cleared LOW on the compare
; match.  Duty Cycle (POS) = CMP2 / (PER + 1).
; 
; 23.2 Overview
;   By default, the TCA is a 16-bit timer/counter and can be used as a 16-bit
;   timer or as two 8-bit timers. In this example, it is used as a 16-bit timer,
;   which means the addressing uses TCA0.SINGLE.REGISTER for the registers and 
;   TCA_SINGLE_CLKSEL_DIV1_gc for the bit masks and group configurations.
;
; 23.3.3.4.3 Single-Slope PWM Generation
;   For single-slope Pulse-Width Modulation (PWM) generation, the TCAn.PER register 
;   controls the period (T), while the TCAn.CMPn register values control the 
;   duty cycles of the generated waveforms.
;
;   F_CPU = 4 MHz, prescaler = 1, PER = 65535  ->  freq = 4 MHz / 65536 = 61Hz
;   DC  = 50, 50% duty cycle, calculated at compile, (DC * (PERIOD + 1)) / 100
; =============================================================

#include <avr/io.h>
#include "registers.S"

; ---------- Pin / register aliases ----------
; 17.3.6 TCAn Pin Position
;   Name: TCAROUTEA
;   Offset: 0x07
;   Reset: 0x00 - WO0 - WO5 => PA0 - PA5, default, TCA0 signals to go to PORTA
#define WO2_PIN     2                                   // PA2 == TCA0 WO2
#define WGM_SINGLESLOPE  (0x3 << TCA_SINGLE_WGMODE_gp)  // CTRLB: single-slope PWM

; ---------- PWM parameters ----------
.equ    PERIOD, 0xfffe                      ; TOP -> 65534 steps, 61Hz @ 4 MHz
.equ    DC, 50                              ; duty cycle (% = DC/PERIOD)
.equ    COMPARE, (DC * (PERIOD + 1)) / 100  ; compare value for the duty cycle

; -------------------- Interrupt vector table --------------------
; No interrupts, only vector 0 (RESET) is ever taken
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler                   ; vector 0  RESET

.section .text

reset_handler:
    ; --- PA2 defaults as WO2 output, see TCAROUTEA
    ; 1. Set PA2 as output for WO2 waveform
    sbi     VPA_DIR, WO2_PIN

    ; --- TCA0 SINGLE (16-bit) Normal operation single-slope PWM on WO2 ---
    ; 2. load the period (PER)
    ldi     temp_16, lo8(PERIOD)
    sts     TCA0_SINGLE_PERL, temp_16
    ldi     temp_16, hi8(PERIOD)
    sts     TCA0_SINGLE_PERH, temp_16       ; PER = period (sets PWM frequency)

    ; 3. load the compare (CMP), CMP/PER = duty cycle
    ldi     temp_16, lo8(COMPARE)
    sts     TCA0_SINGLE_CMP2L, temp_16
    ldi     temp_16, hi8(COMPARE)
    sts     TCA0_SINGLE_CMP2H, temp_16      ; CMP2 = duty cycle on WO2

    ; 4. set the operating mode WGM = 0x3 Single-slope PWM and output on WO2
    ldi     temp_16, WGM_SINGLESLOPE | TCA_SINGLE_CMP2EN_bm
    sts     TCA0_SINGLE_CTRLB, temp_16      ; single-slope PWM, enable WO2 output

    ; 5. set CLKSEL 0x0 (/1) and enable peripheral, this starts waveform
    ldi     temp_16, TCA_SINGLE_ENABLE_bm   ; CLKSEL = DIV1 (0), ENABLE = 1
    sts     TCA0_SINGLE_CTRLA, temp_16      ; start the timer

main_loop:                                  ; infinite loop
    rjmp    main_loop                       ; PWM runs autonomously in hardware

.section .data
.section .bss
