// blink_pwm - PWM on any pin by setting up a PWM via interrupts
// based on code by Mike Williams, Make AVR book
// uses asm commands where possible to save memory

#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <avr/cpufunc.h>
#include "ATtiny.h"

#define GREEN PB4
#define YELLOW PB3

volatile uint8_t A_pulse = 0;
volatile uint8_t B_pulse = 0;

// ISR to set the pin high and the PWM frequency
ISR(TIM0_OVF_vect) 
{
    OCR0A = A_pulse;
    OCR0B = B_pulse;
    SBI(PORTB, GREEN);
    SBI(PORTB, YELLOW);
}

// ISR to set the pin low, thus the duty cycle of the A_pulse
ISR(TIM0_COMPA_vect) 
{
    CBI(PORTB, GREEN);
}

// ISR to set the pin low, thus the duty cycle of the B_pulse
ISR(TIM0_COMPB_vect) 
{
    CBI(PORTB, YELLOW); 
}

int main(void) 
{
    // setup clock for hybrid PWM operation
    TCCR0A = 0 ;                                        // Normal operation 
    TCCR0B |= ( _BV(CS01)) ;                            // /8 prescalar
    TIMSK0 |= (_BV(OCIE0B) | _BV(OCIE0A) | _BV(TOIE0)); // turn on all interrupts
    sei();

    // set both pins to be outputs
    SBI(DDRB, GREEN);
    SBI(DDRB, YELLOW);

    // loop can be used to adjust duty cycle of two pwm signals
    while (1)
    {
        uint8_t t = 255;
        do
        {
            A_pulse = 255 - t;
            B_pulse = t;
            _delay_ms(1);
        } while(--t);
        _delay_ms(100);
    }                                         
  return 0;                            // This line is never reached 
}
