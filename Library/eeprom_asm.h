// eeprom_asm.h
// C declarations for the assembly routines in eeprom.S
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Set the EEPROM read pointer. Only the low 6 bits are used on ATtiny13A
// (64-byte EEPROM); the upper bits are ignored by the hardware.
void eeprom_read_init(uint8_t addr);

// Return the byte at the current address, then advance the address by one
// (wrapping at 64). Address is passed via the EEAR hardware register.
uint8_t eeprom_read_next(void);

#ifdef __cplusplus
}
#endif
