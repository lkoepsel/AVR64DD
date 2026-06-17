// readADCi - reads the ADC using interrupts
// with /16 prescaler, reads at 19kHz
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <util/atomic.h>

// -------- Functions --------- //
#define ADC_VAL 0
#define ADC_CON 1
#define ADC_PIN 4

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
    DDRB |= (_BV(ADC_VAL) | _BV(ADC_CON));  // PB0 as output
    // Make sure PB4 is an input (it should be by default)
    DDRB &= ~_BV(ADC_PIN);  // Clear DDB2 to ensure PB2 is input

    ADCSRA |= _BV(ADSC);                    // start initial ADC conversion

    for (;;)
    {
        uint16_t result = read_ADC();                  // read ADC value
        asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (ADC_CON));

        // For debugging: toggle LED based on threshold
        if (result > 512) {
            PORTB |= _BV(ADC_VAL);   // LED on
        } else {
            PORTB &= ~_BV(ADC_VAL);  // LED off
        }

    }
}
