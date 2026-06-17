// soft serial - software-defined serial port using assembly primitives
// Change serial pins and timing in Library/registers.S and Library/serial.S

#include <avr/pgmspace.h>
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
    init_serial();

    char_write(CR);
    char_write(LF);
    pgmtext_write(prompt);
    char_write(CR);
    char_write(LF);
    pgmtext_write(waiting);

    // Echo each received character back over the serial port.
    for (;;) {
        char_write(char_read());
    }
}
