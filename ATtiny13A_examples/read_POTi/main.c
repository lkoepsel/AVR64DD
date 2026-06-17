// read_POTi - program to read POT and light led based on value, using interrupts
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <util/atomic.h>

#define GREEN PB0
#define YELLOW PB1
#define BLUE PB2
#define POT PB4

#define TOP 682
#define MID 341

// -------- Functions --------- //
// ADC variables
volatile uint16_t ADC_result = 0;

// ADC interrupt - just store the result
ISR(ADC_vect)      
{
    ADC_result = ADC;
}

// Thread-safe ADC result reading
uint16_t read_ADC(void) 
{
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE)
    {
        return ADC_result;
    }
    return 0;   
}

// ADC initialization for potentiometer on PB2 (ADC1)
static inline void initADC(void) 
{
    // Select ADC2 (PB4), VCC as reference
    ADMUX = _BV(MUX1);  // Select ADC1 (PB4)
    
    // Enable ADC with prescaler /16, enable interrupts and auto-trigger
    ADCSRA = _BV(ADEN) | _BV(ADIE) | _BV(ADATE) | _BV(ADPS2);
    sei();
}

int main(void)
{
    initADC();

    /* set pins to output */
    DDRB |=( _BV(GREEN) | _BV(YELLOW) | _BV(BLUE));  // PB0, PB1 and PB2 as outputs
    // Make sure PB4 is an input (it should be by default)
    DDRB &= ~_BV(POT);  // Clear DDB4 to ensure PB4 is input
    PORTB |=( _BV(GREEN) | _BV(YELLOW) | _BV(BLUE));  // set all high
    _delay_ms(500);

    PORTB &= ~( _BV(GREEN) | _BV(YELLOW) | _BV(BLUE));  // set all low
    ADCSRA |= _BV(ADSC);                    // start initial ADC conversion

    for (;;)
    {
        volatile uint16_t result = read_ADC();         // read ADC value

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
