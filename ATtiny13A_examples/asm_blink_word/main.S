; =============================================================
; main  –  Blink LED on LED at 500Hz (1ms on, 1ms off)
; Use 16-bit counter, minimal size by not setting vectors
; Target : ATtiny13A at 1.2MHz (factory default clock)
; Circuit: LED + 220Ω resistor from LED (pin 5) to GND
; =============================================================

#include <avr/io.h>
#include "registers.S"

.section .vectors, "ax", @progbits
    rjmp    reset_handler       ; 0x000  RESET
    ; reti                        ; 0x001  INT0
    ; reti                        ; 0x002  PCINT0
    ; reti                        ; 0x003  TIM0_OVF
    ; reti                        ; 0x004  EE_RDY
    ; reti                        ; 0x005  ANA_COMP
    ; reti                        ; 0x006  TIM0_COMPA
    ; reti                        ; 0x007  TIM0_COMPB
    ; reti                        ; 0x008  WDT
    ; reti                        ; 0x009  ADC

.section .text

; to dial in close to 1ms, use both TRIM and counter
; in this case, counter = 300 and OSCCAL = x64 => 1.003ms
.equ    COUNTER,  300           ; 300@1.2MHZ => 1ms delay
.equ    TRIM, 0x64              ; OSCCAL trim value, typically x6n

reset_handler:                  ; also serves as main_setup
    ldi     r16, TRIM           ; osc trim value
    out     RCCAL, r16         ; nudge oscillator toward true 1.2MHz (maybe)
    eor     r1, r1
    out     STATUS, r1            ; clear status register
    sbi     IO_DDR, LED           ; LED as output

main_loop:
    ldi     R25,hi8(COUNTER)    ; 1 clock cycle, executed once
    ldi     R24,lo8(COUNTER)    ; 1 clock cycle, executed once
    sbi     IO_PIN, LED           ; toggle LED — writing 1 to IO_PIN flips IO_PORT output

    ; ~1ms delay at 1.2MHz
    ; TODO: cycles = 2 × (3×189 + 3) + 4) ~= 1ms (.998ms measured)
    delay_1ms:
        sbiw R24,1
        brne delay_1ms
    rjmp    main_loop

.section .data
.section .bss
