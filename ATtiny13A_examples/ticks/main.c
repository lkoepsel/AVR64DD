// ticks - demonstrate time counter using a system clock
// Sets up a system tick of 1 millisec (1kHz)
// To test, uses the system delay (blocking, doesn't use clock)
// to determine delta between a delay
// _delay_loop_2 - 16-bit blocking delay
//      The loop executes four CPU cycles per iteration
//      not including the overhead the compiler requires
//      to setup the counter register pair.
// Requires init_sysclock()
// Runs ten times, printing the values to console

// Given _delay_loop_2(281) => 1ms, measure 100x281 or 28100:
// using OCRA0 = 0x89 - toggles every 1ms based on scope
// delta_ticks = 0x67 or 103
 
#include <avr/io.h>
#include "serial_asm.h"
#include "sysclock_asm.h"
#include <stdint.h>
#include <util/delay_basic.h>

uint16_t delta_ticks = 0;

int main (void)
{
    // init_sysclock_1k is required to initialize the counter for 1Khz ticks
    init_sysclock_1k ();
    init_serial();

    uint8_t i = 10;
    do
    {
        uint16_t prior_ticks = ticks();
        _delay_loop_2(28100);
        delta_ticks = ticks() - prior_ticks;
        word_write(delta_ticks);
        --i;
    }
    while (i > 0);
    for (;;) {};
}
