// serial_asm.h
// C declarations for the assembly routines in serial.S
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialise TX/RX pin directions and idle state.
// Must be called before char_write or char_read.
void init_serial(void);

// Transmit one byte at 9600-8-N-1.
// The character is passed in r24 per the AVR-GCC ABI.
void char_write(uint8_t c);

// Transmit one word at 9600-8-N-1.
// The character is passed in r25/r24 per the AVR-GCC ABI.
void word_write(uint16_t c);

// Block until one byte is received; return it.
// The result is returned in r24 per the AVR-GCC ABI.
uint8_t char_read(void);

// Write program memory text to console
// The address is passed in r31/r30.
void flash_write(uint16_t addr);

#ifdef __cplusplus
}
#endif
