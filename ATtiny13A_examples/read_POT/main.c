// readPOT - blocking program to read POT and light led based on value
// waits for conversion
#include <avr/io.h>
#include <util/delay.h>

#define GREEN PB0
#define YELLOW PB1
#define BLUE PB2

#define TOP 682
#define MID 341

// -------- Functions --------- //
static inline void initADC0(void) 
{
    // Select ADC1 (PB2) instead of ADC2 to avoid conflict with PB4
    ADMUX = 0;  // Clear ADMUX first
    ADMUX |= _BV(MUX1);  // Select ADC2 (PB4), REFS0 = 0, VCC as reference

    // Enable ADC with prescaler /16 (for 9.6MHz clock → 600kHz ADC clock)
    ADCSRA = _BV(ADEN) | _BV(ADPS2);
}

int main(void)
{
    initADC0();

    /* set pins to output */
    DDRB |=( _BV(GREEN) | _BV(YELLOW) | _BV(BLUE));  // PB4 and PB3 as outputs
    // Make sure PB2 is an input (it should be by default)
    DDRB &= ~_BV(DDB4);  // Clear DDB4 to ensure PB4 is input
    PORTB |=( _BV(GREEN) | _BV(YELLOW) | _BV(BLUE));  // set all high
    _delay_ms(500);

    PORTB &= ~( _BV(GREEN) | _BV(YELLOW) | _BV(BLUE));  // set all high
    for (;;)
    {
        ADCSRA |= _BV(ADSC);                    // start ADC conversion
        loop_until_bit_is_clear(ADCSRA, ADSC);  // wait until done
        volatile uint16_t result = ADC;         // read ADC value

        // For debugging: toggle LED based on threshold
        if (result > TOP) 
        {
            PORTB |= _BV(BLUE);   // GREEN on, others off
            PORTB &= ~_BV(YELLOW) & ~_BV(GREEN);
        }
        else if (result > 340)
        {
            PORTB |= _BV(YELLOW);   // YELLOW on, others off
            PORTB &= ~_BV(GREEN) & ~_BV(BLUE);
        }
        else
        {
            PORTB |= _BV(GREEN);  // BLUE ON, others off
            PORTB &= ~_BV(YELLOW) & ~_BV(BLUE);
        }

    }
}
