// readADC - blocking program to read ADC, waits for conversion
// with /16 prescaler, reads at 2.4kHz
#include <avr/io.h>
#include <util/delay.h>

#define ADC_VAL 0
#define ADC_CON 1
#define ADC_PIN 4

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
    DDRB |= (_BV(ADC_VAL) | _BV(ADC_CON));  // PB0 as output
    // Make sure PB4 is an input (it should be by default)
    DDRB &= ~_BV(ADC_PIN);  // Clear DDB2 to ensure PB2 is input

    for (;;)
    {
        ADCSRA |= _BV(ADSC);                    // start ADC conversion
        loop_until_bit_is_clear(ADCSRA, ADSC);  // wait until done
        uint16_t result = ADC;                  // read ADC value
        asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (ADC_CON));

        // For debugging: toggle LED based on threshold
        if (result > 512) {
            PORTB |= _BV(ADC_VAL);   // LED on
        } else {
            PORTB &= ~_BV(ADC_VAL);  // LED off
        }

    }
}
