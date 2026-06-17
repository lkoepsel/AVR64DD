// t0us - demonstrate timer counter 0
// need to confirm accuracy
//  OSCCAL set to 0x73 for these measurements
//  baud_ticks 156 // 1200 baud -> 835.2us /8
//  baud_ticks 77 // 2400 baud -> 414.6us /8
//  baud_ticks 38 // 4800 baud -> 206.4us /8
//  baud_ticks 155 // 9600 baud -> 104.2us /1

#include <avr/io.h>
#include "ATtiny.h"
// #define baud_ticks 151 // 9600 baud -> 104.2us

int main (void)
{
    // set pin to output
    DDRB |= (_BV(PORTB4));
    TCCR0B = (1 << CS00);  // Prescaler /1
    OSCCAL = 0x73;
    volatile uint8_t baud_ticks = 151;

    do
    {
        
        SBI(PORTB, PORTB4);
        TCNT0 = 0;
        while (TCNT0 < baud_ticks) {} ;
        CBI(PORTB, PORTB4);
        TCNT0 = 0;
        while (TCNT0 < baud_ticks) {} ;
    } while (1);
}
