// sysclock_asm.h
// C declarations for the assembly routines in sysclock.S
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize Timer0 CTC for a 1 kHz system tick. Enables global interrupts.
void init_sysclock_1k(void);

// Return the current 16-bit tick counter (incremented once per millisecond).
uint16_t ticks(void);

#ifdef __cplusplus
}
#endif
