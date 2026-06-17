; =============================================================
; main  –  PWM Output, no prescalar 4.51kHz, signal on LED
; Target : ATtiny13A at 1.2MHz (factory default clock)
; Circuit: LED + 220Ω resistor from LED (pin 5) to GND
; ---------- Timer setup -------------------
; Internal RC-Oscillator = 9,600,000 Hz
; Clock prescaler CLKPR = 8
; Internal contr. clock = 1,200,000 Hz
; TC0 precaler = 1,024
; TC0 tick = 1,171.875 /s
; =============================================================

#include <avr/io.h>
#include "registers.S"

.section .vectors, "ax", @progbits
    rjmp    main_setup       ; 0x000  RESET
    reti                        ; 0x001  INT0
    reti                        ; 0x002  PCINT0
    reti                        ; 0x003  TIM0_OVF
    reti                        ; 0x004  EE_RDY
    reti                        ; 0x005  ANA_COMP
    reti                        ; 0x006  TIM0_COMPA
    reti                        ; 0x007  TIM0_COMPB
    reti                        ; 0x008  WDT
    reti                        ; 0x009  ADC

.section .text

; ---------- Registers and Values ----------------
; R18                           ; Multi purpose register

.equ    DC, 25                  ; duty cycle (%)
.equ    DC_FACTOR, (DC * 255) / 100    ; calculation for duty cycle

main_setup:                  ; also serves as main_setup
    ldi     r16, lo8(RAMEND)    ; init stack
    out     STACK_LOW, r16      ; ATtiny13A has no SPH
    eor     r1, r1
    out     STATUS, r1          ; clear status register
    sbi     IO_DDR, LED         ; LED as output

    ; TCCRA: Fast PWM, use OCRA to adjust width (duty cycle)
    ldi     r18,(1<<COM0A1) | (1<<WGM01) | (1<<WGM00)
    out     TCCRA,R18

    ; TCCRB: no prescaler, 4.51kHz
    ldi     r18, (1<<CS00)      ;
    out     TCCRB,R18          ;

    ; OCRA: Use DC_FACTOR to adjust duty cycle
    ldi     r18,DC_FACTOR       ;
    out     OCRA,r18           ;

main_loop:
    rjmp main_loop

.section .data
.section .bss
