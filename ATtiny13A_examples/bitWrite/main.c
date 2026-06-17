// bitWrite - use serial port to control value on pins PB0-PB2
// Change serial pins and timing in Library/registers.S and Library/serial.S

#include <avr/pgmspace.h>
#include <avr/io.h>
#include "serial_asm.h"

#define CR 13
#define LF 10

const char prompt[]  PROGMEM = "A";
const char waiting[] PROGMEM = "?";

// Write a PROGMEM-resident, null-terminated string to the serial port.
static void pgmtext_write(const char *p)
{
    for (uint8_t c; (c = pgm_read_byte(p)); p++)
        char_write(c);
}

int main(void)
{
    /* set pin to output*/
    DDRB |= (_BV(PORTB2) | _BV(PORTB1) | _BV(PORTB0));

    init_serial();

    char_write(CR);
    char_write(LF);
    pgmtext_write(prompt);
    char_write(CR);
    char_write(LF);
    pgmtext_write(waiting);

    // Echo each received character back over the serial port.
    for (;;) {
        uint8_t bits = char_read();
        char_write(bits);

        bits -= 0x30;
        if (bits <= 7)
        {
            PORTB = (PORTB & ~0x07) | (bits & 0x07);
        }
        else
        {
            pgmtext_write(waiting);        
        }
    }
}
