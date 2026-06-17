//  blink_macro - uses bit creating a macro for the asm commands
//  For smallest code size, set LIBRARY = no_lib in env.make 
//  Using the asm commands, ensures the specific method desired is used
//  In this case, sbi is used to set the bit in PORTB, cbi to clear
//  Testing has confirmed _BV doesn't always use SBI

#include <avr/io.h>
#include <util/delay.h>
#include "ATtiny.h"

#define GREEN 1
#define delay 1000

int main(void)
{
    /* set pin to output*/
    SBI(DDRB, GREEN);

    for(;;) 
    {
        /* turn led on and off */
        SBI(PORTB, GREEN);
        _delay_ms(delay);
        CBI(PORTB, GREEN);
        _delay_ms(delay);
    }
    return 0; 
}
