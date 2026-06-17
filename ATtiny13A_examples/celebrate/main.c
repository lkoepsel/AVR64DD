#include <avr/io.h>
#include <util/delay.h>
#include <avr/cpufunc.h>
#include "ATtiny.h"

// Define hardware, RED/BLUE/GREEN/BUTTON
#define GREEN PB2
#define BLUE PB1
#define RED PB0

void blink(uint8_t b)
{
    do
    {
        SBI(PORTB, RED);
        _delay_ms(125);
        CBI(PORTB, RED);
        SBI(PORTB, BLUE);
        _delay_ms(125);
        CBI(PORTB, BLUE);
        SBI(PORTB, GREEN);
        _delay_ms(125);
        CBI(PORTB, GREEN);
    } while(--b);     
}

int main(void)
{
    for (;;)
    {   
        DDRB |= (_BV(RED) | _BV(GREEN) | _BV(BLUE));
        volatile uint8_t blinks = 1;
        _NOP();
        blink(blinks);
        _NOP();
    }
}