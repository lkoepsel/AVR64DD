// multitasking_wo_delay - one line kernal for multitasking w/o delay

#include <avr/io.h>
#include "sysclock.h"


#define YELLOW_INTERVAL 2000
#define WHITE_INTERVAL 1000
#define RED_INTERVAL 500

#define YELLOW 0        // yellow LED to pin 0
#define WHITE 1         // white LED to pin 3
#define RED 2           // red LED to pin 4


int main(void)
{
  uint16_t yellow_ticks= 0;        // will store last time LED was updated
  uint16_t white_ticks= 0;        // will store last time LED was updated
  uint32_t red_ticks= 0;        // will store last time LED was updated

  // Set up a system tick of 1 millisec (1kHz)
  init_sysclock_1k ();

  DDRB |= (_BV(YELLOW) | _BV(WHITE) | _BV(RED));

    while(1)
    {
        // check to see if it's time to blink the LED; that is, if the 
        // difference between the current time and last time you blinked 
        // the LED is bigger than the interval at which you want to 
        // blink the LED.
        uint32_t current_ticks = ticks();

        if(current_ticks - yellow_ticks > YELLOW_INTERVAL) 
        {
        // save the last time you blinked the LED 
        yellow_ticks = current_ticks;   
        // toggle the state of the LED
          asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (YELLOW));

        }

        if(current_ticks - white_ticks > WHITE_INTERVAL) 
        {
        // save the last time you blinked the LED 
        white_ticks = current_ticks;   
        // toggle the state of the LED
        asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (WHITE));
        }

        if(current_ticks - red_ticks> RED_INTERVAL) 
        {
        // save the last time you blinked the LED 
        red_ticks= current_ticks;   
        // toggle the state of the LED
        asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PINB)), "I" (RED));
        }

    }

}

