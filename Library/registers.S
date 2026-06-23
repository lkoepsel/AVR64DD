; AVR64DD32 
; Register and other definitions required for assembly files
#ifndef REGISTERS_S
#define REGISTERS_S

; ---------- Pin / register aliases ----------
#define LED         5                          // PF5 == LED0 on the Nano
#define VPA_DIR     _SFR_IO_ADDR(VPORTA_DIR)   // PORTA dir  (VPORT, I/O 0x00)
#define VPA_IN      _SFR_IO_ADDR(VPORTA_IN)    // write 1 -> toggle OUT (0x02)
#define VPA_OUT    _SFR_IO_ADDR(VPORTA_OUT)  // PORTA PORT  (VPORT, I/O 0x00)
#define VPF_DIR     _SFR_IO_ADDR(VPORTF_DIR)   // PORTF dir  (VPORT, I/O 0x14)
#define VPF_IN      _SFR_IO_ADDR(VPORTF_IN)    // write 1 -> toggle OUT (0x16)
#define STACK_LOW   _SFR_IO_ADDR(SPL)
#define STACK_HIGH  _SFR_IO_ADDR(SPH)
#define STATUS      _SFR_IO_ADDR(SREG)


#define ticks_lo    r8                          // used in sys_clock ISR for ticks
#define ticks_hi    r9                          // used in sys_clock ISR for ticks
#define char_reg    r24                         // serial: byte to send / received
#define temp_16    r16
#define temp_17    r17
#define delay_18   r18
#define delay_19   r19
#define temp_20    r20
#define temp_21    r21
#define temp_22    r22

.macro  delay_8  ticks
    ldi     delay_18, \ticks
9:  dec     delay_18
    brne    9b
.endm

.macro  delay_16  ticks
    ldi     delay_18, lo8(\ticks)
    ldi     delay_19, hi8(\ticks)
9:  subi    delay_18, 1
    sbci    delay_19, 0
    brne    9b
.endm

#endif  /* REGISTERS_S */
