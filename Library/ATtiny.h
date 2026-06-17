// ATtinylib: C Library of macros and defines for ATtiny13A

#ifndef ATTINYLIB_H
#define ATTINYLIB_H

#include <stdlib.h>
#include <avr/io.h>

    register uint16_t ticks asm("r8");

    #define SBI(port, bit) \
    __asm__ __volatile__ ( \
        "sbi %0, %1" \
        : \
        : "I" (_SFR_IO_ADDR(port)), \
            "I" (bit) \
    )

    #define CBI(port, bit) \
    __asm__ __volatile__ ( \
        "cbi %0, %1" \
        : \
        : "I" (_SFR_IO_ADDR(port)), \
            "I" (bit) \
    )

#endif
