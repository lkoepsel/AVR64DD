//  prng_button - pseudorandom number generator, based on Xorshift family of prngs
//  uses the length of a button press as the seed value 
//  produces numbers 0-255 which are moderately random by inspection

#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <avr/cpufunc.h>
#include <stdbool.h>
#include "ATtiny.h"

#define LED PB0
#define BUTTON PB3

volatile uint8_t ticks_ctr = 0;

// Incrments ticks_ctr for measuring time
ISR (TIM0_COMPA_vect)      
{
    ticks_ctr++;

    // DEBUG: Use to check frequency, currently 200Hz (1/(25ms * 2))
    // SBI(PINB, PB3);
}

// Initialize timer to ~40 ticks for 1 seconds (1 tick = 25ms or max = ~6.5)
// Initialize timer 0 to CTC Mode using OCR0A, with a chip clock of 1.2Mhz
// The values below will result in a ~62.5Hz counter (40 ticks = 1 second)
// CTC mode (WGM0[2:0] = 2)
// Set clock select to /256 CS => 100
// Bit 2 – OCIE0A: Timer/Counter0 Output Compare Match A Interrupt Enable
// OCR0A = x75
// TC0 Register Values, as working
// "GTCCR", 0x00000048, 0x00 (0, 0b00000000), PSR10: 0b0, TSM: 0b0
// "OCR0B", 0x00000049, 0x00 (0, 0b00000000)
// "TCCR0A", 0x0000004F, 0x02 (2, 0b00000010), WGM0: 0b10, COM0B: 0b00, COM0A: 0b00
// "TCNT0", 0x00000052, 0x4C (76, 0b01001100)
// "TCCR0B", 0x00000053, 0x04 (4, 0b00000100), CS0: 0b100, WGM02: 0b0, FOC0B: 0b0, FOC0A: 0b0
// "OCR0A", 0x00000056, 0x75 (117, 0b01110101)
// "TIFR0", 0x00000058, 0x08 (8, 0b00001000), TOV0: 0b0, OCF0A: 0b0, OCF0B: 0b1
// "TIMSK0", 0x00000059, 0x04 (4, 0b00000100), TOIE0: 0b0, OCIE0A: 0b1, OCIE0B: 0b0
void init_sysclock (void)          
{
    TCCR0A = ( _BV(WGM01) ) ; 
    TCCR0B |= ( _BV(CS02) ) ;
    TIMSK0 |= _BV(OCIE0A);
    OCR0A = 0x75;
    sei();
 }

// press_time - returns how long a button has been pressed
 uint8_t press_time(void)
{
    // button_start timer
    uint8_t button_end;
    
    // When button is pressed, determine PRESS_TIME
    static uint8_t button_state = 0;
    bool PRESSED = false;
    bool DOWN = false;
    CBI (PORTB, LED);

    while (!PRESSED)
    {
        // Shift previous states left and add current state
        button_state = (button_state << 1) | (!(PINB & (1 << BUTTON))) | 0xE0;
        // Button is pressed when last 5 readings are all low (pressed)
        if (button_state == 0xff) 
        {
            DOWN = true;
            cli();
            ticks_ctr = 0;
            sei();
        }
        while (DOWN)
        {
            button_state = (button_state << 1) | (!(PINB & (1 << BUTTON)));
            if (button_state == 0xF0) 
            {
                PRESSED = true;
                button_end = ticks_ctr;
                DOWN = false;
            }        
        }
    }
    return button_end;
}

int main(void)
{
    // Initialize timer for a max of ~6.5s (1 tick = 25ms)
        init_sysclock ();

        // DEBUG: temp pin for determing freq
        // DDRB |= (_BV(PB3));

        // setup BUTTON to INPUT PULLUP (set to DDRD to INPUT then set PORTB)
        CBI(DDRB, BUTTON);
        SBI(PORTB, BUTTON);

        uint8_t i = 100;
    volatile uint8_t rand = press_time();
    do
    {   
        rand ^= rand << 1;
        rand ^= rand >> 1;
        rand ^= rand << 2;
        rand = rand % 200 + 1;
        _NOP();
    } while (--i);
    return 0;
}
