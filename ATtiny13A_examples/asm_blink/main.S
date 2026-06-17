; =============================================================
; main  –  Blink LED on PB0 at ~10Hz (50ms on, 50ms off)
; Target : ATtiny13A at 1.2MHz (factory default clock)
; Circuit: LED + 220Ω resistor from PB0 (pin 5) to GND
; =============================================================

#include <avr/io.h>
#include "registers.S"

.section .vectors, "ax", @progbits
    rjmp    reset_handler       ; 0x000  RESET
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

reset_handler:                  ; also serves as main_setup
    ldi     temp_16, lo8(RAMEND)    ; init stack
    out     STACK_LOW, temp_16      ; ATtiny13A has no SPH
    eor     r1, r1
    out     STATUS, r1          ; clear status register
    sbi     IO_DDR, LED         ; PB0 as output

main_loop:
    sbi     IO_PIN, LED         ; toggle LED — writing 1 to PIN flips PORT output
    rcall   delay_1ms
    rjmp    main_loop

; ~50ms width at 1.2MHz
; cycles = (80 × ((3×250 + 3)) + 4 ~= 50.183ms calculated (52.2ms measured)
; inner loop ~= 627us calculated, 662 us measured
delay_1ms:
    ldi     temp_17, 80
outer:
    ldi     temp_16, 250
inner:
    dec     temp_16
    brne    inner
    dec     temp_17
    brne    outer
    ret

.section .data
.section .bss
