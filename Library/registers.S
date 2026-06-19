; AVR64DD32 
; Register and other definitions required for assembly files
#ifndef REGISTERS_S
#define REGISTERS_S

; ---------- Pin / register aliases ----------
#define LED         5                          // PF5 == LED0 on the Nano
#define PORTF_DIR   _SFR_IO_ADDR(VPORTF_DIR)   // PORTF data-direction  (0x14)
#define PORTF_IN    _SFR_IO_ADDR(VPORTF_IN)    // write 1 -> toggle OUT (0x16)
#define STACK_LOW   _SFR_IO_ADDR(SPL)
#define STACK_HIGH  _SFR_IO_ADDR(SPH)
#define STATUS      _SFR_IO_ADDR(SREG)


#define temp_16    r16
#define temp_18    r18
#define temp_19    r19
#define temp_20    r20

.macro  delay_8  ticks
    ldi     temp_19, \ticks
9:  dec     temp_19
    brne    9b
.endm

.macro  delay_16  ticks
    ldi     temp_18, lo8(\ticks)
    ldi     temp_19, hi8(\ticks)
9:  subi    temp_18, 1
    sbci    temp_19, 0
    brne    9b
.endm

#endif  /* REGISTERS_S */
