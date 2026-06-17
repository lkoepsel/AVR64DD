// sysclock - use ticks() which returns a long int of current tick counter
// Sets up a system tick of 62.5ns or 16MHz
// To test, uses the system delay (blocking, doesn't use clock)
// Measure pre-delay, measure post-delay, determine delta 
// between a delay then shift right by 4 to get microseconds
// 
// The three Timer/Counters are used in the following manner:
// T/C 0 - sys_clock (and only clock)

#ifndef sysclock_h
#define sysclock_h

#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>

uint16_t ticks(void);

void init_sysclock_1k (void);

#endif
