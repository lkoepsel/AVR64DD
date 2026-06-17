#include "sysclock.h"
#include <util/atomic.h>
#include <avr/interrupt.h>

// ****Defined Interrupt Service Routines****
volatile uint16_t ticks_ctr = 0;

// Required for ticks timing, see examples/ticks
// Enabled by init_sysclock_1() in sysclock.c
ISR (TIM0_COMPA_vect)      
{
    // ticks_ctr++;
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (0));

}

// ****End of Defined Interrupt Service Routines****

// ****Defined Timer Setup Functions****
void init_sysclock_1k (void)          
{
    // Initialize timer 0 to CTC Mode using OCR0A, with a chip clock of 1.2Mhz
    // The values below will result in a 1kHz counter (1000 ticks = 1 second)
    // CTC mode (WGM0[2:0] = 2)
    // Set clock select to /8 CS => 010
    // Bit 2 – OCIE0A: Timer/Counter0 Output Compare Match A Interrupt Enable
    // COM0A0 - set to view OC0A on PB0 with scope
    // OCR0A = x9c or ~150

    // TCCR0A [ COM0A1 COM0A0 COM0B1 COM0B0 0 0 WGM01 WGM00 ] = 0b01000010
    // TCCR0B [ FOC0A FOC0B 0 0 WGM02 CS02 CS01 CS00 ] = 0b00000010
    // TIMSK0 [ 0 0 0 0  OCIE0B  OCIE0A  TOIE0 0 ] = 0b00000100
    // OCR0A = 0x9a
    // tick = 1/1000 second
    // Test using example/ticks w/ _delay_ms(1000); = 1000 ticks

    TCCR0A = ( _BV(COM0A0) | _BV(WGM01) ) ; 
    TCCR0B |= ( _BV(CS01) ) ;
    TIMSK0 |= _BV(OCIE0A);
    OCR0A = 0x79;
    sei();
 
    /* set pin to output to view OC0A*/
    DDRB |= (_BV(PORTB0));
}

// ****End of Defined Timer Setup Functions****

uint16_t ticks(void) {
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE)
    {
        return(ticks_ctr);
    }
    return 0;   
}

