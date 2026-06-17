// button - program to read a pin to demo button presses
// Uses blocking and 5 consecutive reads to confirm a button press
// Lights an LED to indicate a pressed button

#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>
#include "ATtiny.h"

#define LED PB0
#define BUTTON PB4

int main(void)
{
    // set LED pin to OUTPUT
    SBI(DDRB, LED);

    // set BUTTON to INPUT PULLUP (set to DDRD to INPUT then set PORTB)
    CBI(DDRB, BUTTON);
    SBI(PORTB, BUTTON);

    for (;;) 
    {
        static uint8_t button_state = 0;
        bool PRESSED = false;
        CBI (PORTB, LED);

        while (!PRESSED)
        {
            // Shift previous states left and add current state
            button_state = (button_state << 1) | (!(PINB & (1 << BUTTON))) | 0xE0;

            // Button is pressed when last 5 readings are all low (pressed)
            if (button_state == 0xF0) 
            {
                PRESSED = true;
                SBI(PORTB, LED);

                // delay to show LED
                _delay_ms(5);
            }
        }
    }
}  
