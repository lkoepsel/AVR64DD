// multitasking_blocking - One line kernal for multitasking
// https://www.embedded.com/a-multitasking-kernel-in-one-line-of-code-almost/
// Designed to demonstrate the 13A performing different tasks
// with different delays, using a single function pointer array.

#include <avr/io.h>
#include <util/delay.h>

#define NTASKS 8

void zero (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB0));
    _delay_ms(200);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB0));
    return;
} 

void one (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB1));
    _delay_ms(100);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB1));
    return;
} 

void two (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    _delay_ms(500);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    return;
} 

void three (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    _delay_ms(500);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    return;
} 

void four (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB0));
    _delay_ms(200);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB0));
    return;
} 

void five (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB1));
    _delay_ms(100);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB1));
    return;
} 

void six (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    _delay_ms(500);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    return;
} 

void seven (void) {
    /* toggle led on and off */
    asm ("sbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    _delay_ms(500);
    asm ("cbi %0, %1 \n" : : "I" (_SFR_IO_ADDR(PORTB)), "I" (PINB2));
    return;
} 

void (*tasklist[NTASKS])() = {zero, one, two, three, four, five, six, seven};

int main(void)
{
    DDRB |= (_BV(PINB0) | _BV(PINB1) | _BV(PINB2));

    while (1)
    {
    for (uint8_t taskcount=0; taskcount < NTASKS; ++taskcount)
        {
            (*tasklist[taskcount])();

        }
    }
    return 0; 
}

