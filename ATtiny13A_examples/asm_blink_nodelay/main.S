; =============================================================
; main  –  Output 100ms signal on LED
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

; ---------- Registers ----------------
; R18                           ; Multi purpose register

.equ    COUNT_A, 0x70           ; measured 100.4ms

main_setup:                  ; also serves as main_setup
    ldi     r16, lo8(RAMEND)    ; init stack
    out     STACK_LOW, r16            ; ATtiny13A has no SPH
    eor     r1, r1
    out     STATUS, r1            ; clear status register
    sbi     IO_DDR, LED           ; LED as output

    ; OCRA: Use COUNT_A for Compare Match
    ldi     r18,COUNT_A         ; Match at COUNT_A
    out     OCRA,R18           ;

    ; TCCRA: Toggle LED at Compare Match to OCRA (CTC mode)
    ldi     r18,(1<<COM0A0) |(1<<WGM01)
    out     TCCRA,R18

    ; TCCRB: 1/1024 prescaler
    ldi     r18,(1<<CS02)|(1<<CS00) ; prescaler 1024
    out     TCCRB,R18          ; to control port B

main_loop:
    rjmp main_loop

.section .data
.section .bss
