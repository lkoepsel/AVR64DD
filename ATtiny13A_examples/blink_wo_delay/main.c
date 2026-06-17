// blink_wo_delay - C version
// Based on Arduino tutorial:
// http://www.arduino.cc/en/Tutorial/BlinkWithoutDelay
// And the Adafruit tutorial:
// https://learn.adafruit.com/multi-tasking-the-arduino-part-1?view=all
// Uses asm commands, instead of C, as C doesn't use SBI in _BV

#include "sysclock.h"

#define interval 1000
#define YELLOW 0        // yellow LED to pin 0

volatile uint16_t total_blinks = 0;
volatile uint16_t total_rollover = 0;

int main (void)
{
  // Variables will change:
  uint16_t previous_ticks = 0;        // will store last time LED was updated
  uint16_t last_tick_check = 0;        // will store last time LED was updated

  // Set up a system tick of 1 millisec (1kHz)
  init_sysclock_1k ();

    /* set pin to output*/
    DDRB |= (_BV(YELLOW));

    while(1)
    {
        uint16_t current_ticks = ticks();

        // check to see if it's time to blink the LED; that is, if the 
        // difference between the current time and last time you blinked 
        // the LED is bigger than the interval at which you want to 
        // blink the LED.
        if(current_ticks - previous_ticks >= interval ) 
        {
            // save the last time you blinked the LED 
            previous_ticks = current_ticks;   
            total_blinks++;
            // toggle the state of the LED
            asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (YELLOW));
        }

        if (current_ticks < last_tick_check)
        {
            total_rollover++;
        }
        last_tick_check = current_ticks;   
    }
}
