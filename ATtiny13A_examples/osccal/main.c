// osccal - sweep OSCCAL and transmit a test pattern via the asm serial
// library so the value that yields clean output is the value to put in
// Library/serial.S (TRIM).
//
// Chip OSCCAL will be printed and the starting OSCCAL value
// will be initially low, to ensure sweep doesn't miss good value.
// Watch the terminal; the OSCCAL=HH lines that read cleanly identify the
// correct trim for this particular chip with this library.

#include <avr/io.h>
#include <avr/pgmspace.h>
#include <util/delay.h>
#include "serial_asm.h"

static const char chip[] PROGMEM = "chip ";
static const char osccal_label[] PROGMEM = "OSCCAL=";
static const char sep[]          PROGMEM = ": ";
static const char pattern[]      PROGMEM = "ABC123\r\n";

static void pgmtext_write(const char *p)
{
    for (uint8_t c; (c = pgm_read_byte(p)); p++)
        char_write(c);
}

static void send_hex_byte(uint8_t value)
{
    uint8_t high = (value >> 4) & 0x0F;
    uint8_t low  = value & 0x0F;
    char_write(high < 10 ? '0' + high : 'A' + high - 10);
    char_write(low  < 10 ? '0' + low  : 'A' + low  - 10);
}

static void emit_line(void)
{
    pgmtext_write(osccal_label);
    send_hex_byte(OSCCAL);
    pgmtext_write(sep);
    pgmtext_write(pattern);
}

int main(void)
{
    init_serial();

    // print OSCCAL value currently on chip for reference
    // start with a low OSCCAL to ensure low values are checked
    pgmtext_write(chip);
    pgmtext_write(osccal_label);
    send_hex_byte(OSCCAL);
    char_write('\r'); 
    char_write('\n');
    uint8_t osccal_start = 0x55;

    while (1)
    {
        for (uint8_t i = 0; i < 128; i++)
        {
            OSCCAL = osccal_start + i;
            emit_line();
            _delay_ms(500);
        }

        for (uint8_t i = 1; i < 128; i++)
        {
            if (osccal_start < i) break;
            OSCCAL = osccal_start - i;
            emit_line();
            _delay_ms(500);
        }

        OSCCAL = osccal_start;
        _delay_ms(2000);
    }
}
