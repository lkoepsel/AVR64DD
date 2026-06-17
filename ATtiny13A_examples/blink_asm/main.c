//  blink_asm - uses bit setting by asm commands
//  Using the asm commands, ensures the specific method desired is used
//  In this case, sbi is used to set the bit in PIN to toggle pin
//  Use this to calibrate RC oscillator as wellF

#include <avr/io.h>
#include <util/delay_basic.h>

#define GREEN 0
#define delay 281       // measured to be 1ms delay (.99921ms avg over 30min)
int main(void)
{
    // Use examples/osccal to determine best value for the particular uC.
    OSCCAL = 0x61;
    // set pin to output
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(DDRB)), "I" (GREEN));

    for(;;)
    {
        // turn led on and off
        asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (GREEN));
        _delay_loop_2(delay);
    }
    return 0;
}
