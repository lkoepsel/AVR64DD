; AVR64DD32 
; Register and other definitions required for assembly files
#ifndef REGISTERS_S
#define REGISTERS_S

; ---------- Pin / register aliases ----------
#define LED         5                          // PF5 == LED0 on the Nano
#define PA2         2                          // PA2 == pin on Nano
#define VPA_DIR     _SFR_IO_ADDR(VPORTA_DIR)   // PORTA dir  (VPORT, I/O 0x00)
#define VPA_IN      _SFR_IO_ADDR(VPORTA_IN)    // write 1 -> toggle OUT (0x02)
#define VPA_OUT     _SFR_IO_ADDR(VPORTA_OUT)  // PORTA PORT  (VPORT, I/O 0x00)
#define VPF_DIR     _SFR_IO_ADDR(VPORTF_DIR)   // PORTF dir  (VPORT, I/O 0x14)
#define VPF_IN      _SFR_IO_ADDR(VPORTF_IN)    // write 1 -> toggle OUT (0x16)
#define STACK_LOW   _SFR_IO_ADDR(SPL)
#define STACK_HIGH  _SFR_IO_ADDR(SPH)
#define STATUS      _SFR_IO_ADDR(SREG)

; register r0       r0      // Claimed, used as scratch register, LPM/SPM, MUL
; register r1       r1      // Claimed, always 0
#define ISR_2       r2      // used in sys_clock ISR for temp register
; free              r3
#define  index_4    r4
; free              r5
; free              r6
; free              r7
#define ticks_8_lo  r8      // used in sys_clock ISR for ticks
#define ticks_9_hi  r9      // used in sys_clock ISR for ticks
; free              r10
; free              r11
; free              r12
; free              r13
; free              r14
; free              r15
#define temp_16     r16
#define temp_17     r17
#define delay_18    r18
#define delay_19    r19
#define temp_20     r20
#define task_21     r21    // used to save the current task running
#define temp_21     r21
#define temp_22     r22
; free              r23
#define char_24     r24     // serial: byte to send / received
; free              r25
#define tasks_26    r26
#define tasks_27    r27
; free              r28
; free              r29
#define Z_30_lo     r30             
#define Z_31_hi     r31


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

#endif  // REGISTERS_S 
