// reaction - simple reaction time game
// FLASH Hash - abde8a134e006204e0ba12f89aed2bb5
// Game Rules
// 1. Light BLUE between .5 and 2 seconds
// 2. Blink GREEN to start.
// 3. User must press button to match the time of the RED  
// 4. GREEN if acceptable
// 5. RED if not acceptable
// 6. Five chances, at the end, blink GREEN for successful turns and blink RED for unsuccessful

//
//                     ATtiny13
//                   ┌──────────┐
//     RESET/PB5 ──1─┤          ├─8── VCC
//           PB3 ──2─┤          ├─7── PB2/GREEN
//    BUTTON/PB4 ──3─┤          ├─6── PB1/BLUE
//           GND ──4─┤          ├─5── PB0/RED
//                   └──────────┘
//

#include <avr/io.h>
#include <avr/eeprom.h>
#include <util/delay.h>
#include <util/atomic.h>
#include <avr/interrupt.h>
#include <stdbool.h>
#include <inttypes.h>
#include "ATtiny.h"

// Define hardware, RED/BLUE/GREEN/BUTTON
#define GREEN PB2
#define BLUE PB1
#define RED PB0
#define BUTTON PB3
#define TOLERANCE 4

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
    // TCCR0A |= _BV(COM0A0) ; 
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

    while (!PRESSED)
    {
        // Shift previous states left and add current state
        button_state = (button_state << 1) | (!(PINB & (1 << BUTTON))) | 0xE0;
        // Button is pressed when last 5 readings are all low (pressed)
        if (button_state == 0xff) 
        {
            DOWN = true;
            cli();
            ticks_ctr = 0;
            sei();
        }
        while (DOWN)
        {
            button_state = (button_state << 1) | (!(PINB & (1 << BUTTON)));
            if (button_state == 0xF0) 
            {
                PRESSED = true;
                button_end = ticks_ctr;
                DOWN = false;
            }        
        }
    }
    return button_end;
}

void blink(uint8_t b)
{
    do
    {
        SBI(PORTB, RED);
        _delay_ms(125);
        CBI(PORTB, RED);
        SBI(PORTB, BLUE);
        _delay_ms(125);
        CBI(PORTB, BLUE);
        SBI(PORTB, GREEN);
        _delay_ms(125);
        CBI(PORTB, GREEN);
    } while(--b);     
}

// main - infinite loop, doesn't exit
int main (void)
{
    for (;;)
    {
    // Initialize timer for a max of ~6.5s (1 tick = 25ms)
        init_20Hz ();

        // DEBUG: temp pin for determing freq
        // DDRB |= (_BV(OC0A_PIN));

        /* setup LEDs */
        DDRB |=( _BV(BLUE) | _BV(GREEN) | _BV(RED));

        // setup BUTTON to INPUT PULLUP (set to DDRD to INPUT then set PORTB)
        CBI(DDRB, BUTTON);
        SBI(PORTB, BUTTON);

        // Blink all three LEDs to indicate game will start
        PORTB |= ( _BV(BLUE) | _BV(GREEN) | _BV(RED));
        _delay_ms(500);
        PORTB &= ~( _BV(BLUE) | _BV(GREEN) | _BV(RED));
        _delay_ms(500);

        // initialize the pseudorandom number generator using a button press time
        volatile uint8_t rand = press_time();

        _delay_ms(1000);

        volatile uint8_t good = 0;
        uint8_t try = 3;
        do
        {
            // initialize counters
            volatile uint8_t led_delta = 0;

            // Light BLUE with a random delay
            // Use XOR pseudorandom generator
            rand ^= rand << 1;
            rand ^= rand >> 1;
            rand ^= rand << 2;

            // create a range between 20 and 200
            rand = (rand % 128) + 16;

            volatile uint8_t ALLOW = rand / TOLERANCE;
            uint16_t i = rand;

            // start led timer and turn on BLUE led
            uint8_t led_start = ticks_ctr;
            SBI(PORTB, BLUE);
            do
            {
            _delay_ms(25);
            } while(--i);
            CBI(PORTB, BLUE);
            uint8_t led_end = ticks_ctr;

            if (led_start > led_end)
            {
                led_delta = (255 - led_start) + led_end;
            }
            else
            {
                led_delta = led_end - led_start;
            }

            volatile uint8_t button_delta = press_time();

            _delay_ms(500);
            // If CLOSE, blink BLUE else, blink RED
            if ((button_delta < (led_delta + ALLOW)) & (button_delta > (led_delta - ALLOW)))
            {
                SBI(PORTB, GREEN);
                _delay_ms(250);
                CBI(PORTB, GREEN);
                _delay_ms(250);
                ++good;
            }
            // Blink RED for every failure
            else
            {
                SBI(PORTB, RED);
                _delay_ms(250);
                CBI(PORTB, RED);
                _delay_ms(250);
            }       
            _delay_ms(1000);
        
        } while (--try);

        volatile uint8_t blinks = 1 << good;
        blink(blinks);
        _delay_ms(1000);
    }
}