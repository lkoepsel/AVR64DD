; =============================================================
; eeprom  -  sequential EEPROM read for ATtiny13A
; Target : ATtiny13A (64 bytes EEPROM, 6-bit address)
; Toolchain: avr-gcc (preprocessor + assembler)
; =============================================================
;
; The "current read address" lives in the hardware EEAR register
; between calls, so this module uses no SRAM. That assumes nothing
; else in the program touches EEAR between init and the read loop.
;
; Calling convention: AVR-GCC ABI (r24 in, r24 out, r18 scratch).

#include <avr/io.h>

.section .text

; void eeprom_read_init(uint8_t addr)
;   Set the EEPROM read pointer to `addr`. Only the low 6 bits matter
;   on ATtiny13A; the hardware ignores the upper bits.
.global eeprom_read_init
eeprom_read_init:
    out     _SFR_IO_ADDR(EEARL), r24
    ret

; uint8_t eeprom_read_next(void)
;   Read the byte at the current EEAR, then post-increment EEAR.
;   Address wraps at 64 (the EEPROM size on ATtiny13A).
.global eeprom_read_next
eeprom_read_next:
    ; Wait for any in-flight EEPROM write to finish. Reading while
    ; EEPE is set returns garbage on this part.
1:  sbic    _SFR_IO_ADDR(EECR), EEPE
    rjmp    1b

    ; Strobe read. CPU is halted for 4 cycles while the EEPROM responds.
    sbi     _SFR_IO_ADDR(EECR), EERE
    in      r24, _SFR_IO_ADDR(EEDR)

    ; Post-increment EEAR, wrapping at the 64-byte boundary.
    in      r18, _SFR_IO_ADDR(EEARL)
    inc     r18
    andi    r18, 0x3F
    out     _SFR_IO_ADDR(EEARL), r18

    ret
