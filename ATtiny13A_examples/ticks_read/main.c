// ticks_read - demonstrate time counter w/ system clock
// Sets up a system tick of 1 millisec (1kHz) using a CPU clock of 9.6MHz
// CKDIV8 fuse needs to be set to 1
// Use: avrdude -c snap_isp -p attiny13a -U lfuse:w:0x7A:m -U hfuse:w:0xF7:m
// To test, used DIgilent frequency measurement of 499Hz, 1.002ms tick width
 
#include <avr/io.h>
#include <avr/eeprom.h>
#include <util/delay.h>
#include <util/atomic.h>
#include <avr/interrupt.h>
#include "ATtiny.h"

// ****Defined Interrupt Service Routines****
volatile uint16_t ticks_ctr = 0;

// Enabled by init_sysclock_1() in sysclock.c
ISR (TIM0_COMPA_vect)      
{
    // toggle pin every interrupt
    SBI(PINB, PINB0);
}

// ****End of Defined Interrupt Service Routines****

// ****Defined Timer Setup Functions****
void init_sysclock_1k (void)          
{
    // Initialize timer 0 to CTC Mode using OCR0A, with a chip clock of 9.6Mhz
    // This will require the Low Fuse bit 4 CKDIV8 to be set to 1
    // The values below will result in a 1kHz counter (1000 ticks = 1 second)
    // CTC mode (WGM0[2:0] = 2)
    // Set clock select to /8 CS => 010
    // Bit 2 – OCIE0A: Timer/Counter0 Output Compare Match A Interrupt Enable
    // COM0A0 - set to view OC0A on PB0 with scope
    // OCR0A = x91

    // TCCR0A [ COM0A1 COM0A0 COM0B1 COM0B0 0 0 WGM01 WGM00 ] = 0b01000010
    // TCCR0B [ FOC0A FOC0B 0 0 WGM02 CS02 CS01 CS00 ] = 0b00000011
    // TIMSK0 [ 0 0 0 0  OCIE0B  OCIE0A  TOIE0 0 ] = 0b00000100
    // OCR0A = 0x96

    TCCR0A = ( _BV(COM0A0) | _BV(WGM01) ) ; 
    TCCR0B |= ( _BV(CS01) | _BV(CS00)) ;
    TIMSK0 |= _BV(OCIE0A);
    OCR0A = 0x91;
    sei();
}

int main (void)
{
    // init_sysclock_1k is required to initialize the counter for 1Khz ticks
    init_sysclock_1k ();

    /* set pin to output to view OC0A*/
    DDRB |= (_BV(PORTB0));

    for (;;) {};
}
