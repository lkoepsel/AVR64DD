//  prng - pseudorandom number generator, based on Xorshift family of prngs
//  produces numbers 0-255 which are moderately random by inspection

#include <inttypes.h>

int main(void)
{
    uint8_t i = 100;
    volatile uint8_t state = 0xE1;
    do
    {   
        state ^= state << 1;
        state ^= state >> 1;
        state ^= state << 2;
    } while (--i);
    return 0;
}
