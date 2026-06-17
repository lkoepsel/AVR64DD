// button_timed - program to read a pin and time the delta between press and release
// Uses blocking and 5 consecutive reads to confirm a button press and a release
// Uses a 20Hz counter and an 8-bit counter to determine up to ~6s press times
// DEBUG: To confirm freq, set COM0A0 to toggle PB0 on OCR0A compare match 

#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <avr/cpufunc.h>
#include <stdbool.h>
#include "ATtiny.h"

#define LED PB0
#define BUTTON PB3
// DEBUG: This pin will toggle if enabled using COM0A0
#define OC0A_PIN PB0       // (OC0A for ATtiny13A)

volatile uint8_t ticks_ctr = 0;

// Incrments ticks_ctr for measuring time
ISR (TIM0_COMPA_vect)      
{
    ticks_ctr++;
}

// Initialize timer to ~40 ticks for 1 seconds (1 tick = 25.08ms)
// Initialize timer 0 to CTC Mode using OCR0A, with a chip clock of 1.2Mhz
// The values below will result in a ~20Hz counter (2 ticks = 1 period or ~50ms, 40 ticks = 1 second)
// CTC mode (WGM0[2:0] = 2)
// Set clock select to /256 CS => 100
// Bit 2 – OCIE0A: Timer/Counter0 Output Compare Match A Interrupt Enable
// OCR0A = x70
// TC0 Register Values, as working
// `tc0`, `gtccr`, "GTCCR", 0x00000048, 8-bit | 0x00 (0, 0b00000000), PSR10: 0b0, TSM: 0b0
// `tc0`, `ocr0b`, "OCR0B", 0x00000049, 8-bit | 0x00 (0, 0b00000000)
// `tc0`, `tccr0a`, "TCCR0A", 0x0000004F, 8-bit | 0x42 (66, 0b01000010), WGM0: 0b10, COM0B: 0b00, COM0A: 0b01
// `tc0`, `tcnt0`, "TCNT0", 0x00000052, 8-bit | 0x4F (79, 0b01001111)
// `tc0`, `tccr0b`, "TCCR0B", 0x00000053, 8-bit | 0x04 (4, 0b00000100), CS0: 0b100, WGM02: 0b0, FOC0B: 0b0, FOC0A: 0b0
// `tc0`, `ocr0a`, "OCR0A", 0x00000056, 8-bit | 0x70 (112, 0b01110000)
// `tc0`, `tifr0`, "TIFR0", 0x00000058, 8-bit | 0x08 (8, 0b00001000), TOV0: 0b0, OCF0A: 0b0, OCF0B: 0b1
// `tc0`, `timsk0`, "TIMSK0", 0x00000059, 8-bit | 0x04 (4, 0b00000100), TOIE0: 0b0, OCIE0A: 0b1, OCIE0B: 0b0

void init_20Hz (void)          
{
    TCCR0A = _BV(WGM01) ; 
    // DEBUG: show frequency on PB0
    TCCR0A |= _BV(COM0A0) ; 
    TCCR0B |= ( _BV(CS02) ) ;
    TIMSK0 |= _BV(OCIE0A);
    OCR0A = 0x70;
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
        // Button is down when last 5 readings are all low (down)
        if (button_state == 0xff) 
        {
            DOWN = true;
            // reset the counter via interrupt to make the delta easy to calculate
            cli();
            ticks_ctr = 0;
            sei();
        }
        while (DOWN)
        {
            button_state = (button_state << 1) | (!(PINB & (1 << BUTTON)));
            // Button is released when last 5 readings are all high (up)
            if (button_state == 0xF0) 
            {
                // button has been "pressed" (down then up) 
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
        init_20Hz ();

        // DEBUG: OC0A pin for confirming freq, toggles on compare match
        DDRB |= (_BV(OC0A_PIN));

    // set LED pin to OUTPUT
    SBI(DDRB, LED);

    // set BUTTON to INPUT PULLUP (set to DDRD to INPUT then set PORTB)
    CBI(DDRB, BUTTON);
    SBI(PORTB, BUTTON);

    for (;;) 
    {
        volatile uint8_t delta = press_time();
        _NOP();
        do
        {
            SBI(PINB, LED);
            _delay_ms(1);
        } while(--delta);
    }
}  
