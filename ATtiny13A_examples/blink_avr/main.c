//  blink_avr - uses bit toggling bits as compared to Arduino digitalWrite()
//  For smallest code size, set LIBRARY = no_lib in env.make 
//  Smallest code size allows you to use a scope to confirm delay 
//      is exactly 1 millisecond or other timing exercises.
//   For example: (when measured):
//      blink 2.0108s period while avr_blink 2.0022s period for a delay of 1000ms
//      or remove the delays and determine fastest blink is 2.02MHz w/ -Og -ggdb
//      or remove the delays and determine fastest blink is 2.68MHz w/ -Os -g

#include <avr/io.h>
#include <util/delay.h>
 
int main(void)
{
    /* set pin to output*/
    DDRB |= (_BV(PORTB4));

    while(1) 
    {
        /* turn led on and off */
        PINB |= (_BV(PORTB4));
        _delay_ms(500);
    }
    return 0; 
}
