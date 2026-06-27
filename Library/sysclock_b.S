; ====================================================================
;  sysclock_tcb_dd32
;       TCB0_INT_handler   - minimal ISR, increments ticks counter
;       init_sysclock_100u - setup TCB0 for 100us periodic interrupt
;       ticks              - return current 16-bit tick count in r25:r24
; Target : AVR64DD32 (Curiosity Nano)
; Clock  : 4 MHz CLK_PER  (CLK_PER = CLKMAIN, no prescale)
; Toolchain: avr-as / avr-ld  (GNU Binutils for AVR)
; Debugger : Bloom over UPDI  (avr_gdb_rsp @ 127.0.0.1:1442)
; ====================================================================
;
;  Companion to sysclock_dd32.S (TCA0 OVF, 1ms). Differences worth
;  noting for students moving from TCA to TCB:
;
;    * TCB is a 16-bit single-shot/periodic timer. In PERIODIC INT mode
;      (CNTMODE = INT) it counts CLK 0 -> CCMP, fires CAPT, and reloads.
;      No prescaler is needed here: at CLK_PER = 4 MHz one tick = 250 ns.
;    * 100 us = 400 ticks. We count 0..399, so CCMP = 399.
;    * The interrupt flag (CAPT) lives in TCB0.INTFLAGS and is cleared
;      by WRITING A 1 to it -- do this in the ISR or it re-fires forever.
;    * Vector is TCB0_INT_vect. VERIFY the number against your header:
;          grep TCB0_INT_vect /path/to/ioavr64dd32.h
;      It expands to _VECTOR(n); use that n for __vector_n below.
; --------------------------------------------------------------------

; Dependencies — included here so this module assembles standalone
#include <avr/io.h>
#include "registers.S"

; --------------------------------------------------------------------
;  Registers and Values
;
;    r24,r25  - ticks counter (low,high), returned by 'ticks'
;    r2       - ISR scratch: saved SREG  (dedicated low reg, never
;               touched by mainline code -> no push/pop of SREG needed
;               beyond r2 itself; keeps the ISR lean, matching the
;               tiny13 convention)
;    r16,r17  - temps used only by init (mainline context)
;
;    CCMP value : 4 MHz * 100 us = 400 counts -> CCMP = 399 = 0x018F
; --------------------------------------------------------------------

.section .text

; --------------------------------------------------------------------
;  init_sysclock_100u : configure TCB0 for a 100 us periodic interrupt.
;  Call once, with interrupts disabled, before sei.
; --------------------------------------------------------------------
.global init_sysclock_100u
init_sysclock_100u:
    ; --- setup tasks buffer for recording which task is running
    ldi   tasks_26, lo8(tasks)
    ldi   tasks_27, hi8(tasks)

    ; --- compare value: 399 counts (0..399 = 400 ticks = 100 us) ---
    ldi   temp_16, lo8(399)
    ldi   r17, hi8(399)
    sts   TCB0_CCMPL, temp_16          ; CCMP is 16-bit: write L then H
    sts   TCB0_CCMPH, r17

    ; --- clear count ---
    ldi   temp_16, 0
    sts   TCB0_CNTL, temp_16
    sts   TCB0_CNTH, temp_16

    ; --- periodic interrupt mode: CNTMODE = INT ---
    ;    TCB_CNTMODE_INT_gc = (TCB_CNTMODE_INT_gv << TCB_CNTMODE_gp)
    ;    TCB_CNTMODE_INT_gv             = 0x00,  /* Periodic Interrupt */
    ;    #define TCB_CNTMODE_gp  0  /* Timer Mode group position. */

    ldi   temp_16, (0 << 0)
    sts   TCB0_CTRLB, temp_16

    ; --- enable CAPT interrupt ---
    ldi   temp_16, TCB_CAPT_bm
    sts   TCB0_INTCTRL, temp_16

    ; --- clock = CLK_PER (no div), enable timer ---
    ;     TCB_CLKSEL_DIV1_gv             = 0x00,  /* CLK_PER */
    ;     #define TCB_ENABLE_bm  0x01  /* Enable bit mask. */
    ldi   temp_16, (0 << 1) | (1 << 0)
    sts   TCB0_CTRLA, temp_16
    sei
    ret

; --------------------------------------------------------------------
;  TCB0_INT_handler : save task running to buffer
; --------------------------------------------------------------------
.global __vector_14                
__vector_14:
TCB0_INT_handler:
    in    ISR_2, SREG               ; save flags in dedicated low reg

    ldi   temp_17, TCB_CAPT_bm      ; clear CAPT by writing 1
    sts   TCB0_INTFLAGS, temp_17

    st    X+, task_21               ; on interrupt, save task to buffer
    
    ; ring buffer, if at end, reload
    cpi   tasks_26, lo8(tasks + tasks_size)
    brne  lt_buf                    ; less than buffer size
    ldi   tasks_26, lo8(tasks)      ; end of buffer, reload

 lt_buf:   
    out   SREG, ISR_2               ; restore flags
    reti

; ====================================================================
;  DATA SECTION  (initialized variables in SRAM)
; ====================================================================
.section .data

; ====================================================================
;  BSS SECTION  (zero-initialized / uninitialized variables in SRAM)
; ====================================================================
.section .bss
    .equ    tasks_size, 0x80
tasks:
    .space tasks_size                    ; reserve 100 bytes for task storage