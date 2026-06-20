; =============================================================
; main  –  Simplest possible hardware PWM with Timer/Counter A (TCA0)
; Target : AVR64DD32 @ 4 MHz   (factory default: internal OSCHF, no prescale)
; Board  : AVR64DD32 Curiosity Nano
; Build  : freestanding (-nostartfiles -nostdlib): this file owns the
;          interrupt vector table and the reset/setup code.
;
; OUTPUT PIN:  PA2   <-- probe this with the oscilloscope.
;
; Why PA2 (and not the on-board LED): TCA0 waveform outputs WO0..WO5 map to
; pins 0..5 of one port, PORTA by default. The on-board LED is on PF5, which
; is only WO5 and only reachable through TCA0 "Split mode" + PORTMUX routing
; (the complicated earlier version). To keep this as simple as possible we
; use the DEFAULT routing and a normal (non-split) channel instead:
;   * Default PORTMUX -> TCA0 drives PORTA, no routing register touched.
;   * WO0=PA0 and WO1=PA1 are tied to the 24 MHz crystal and are NOT broken
;     out on the Nano edge connector, so the simplest usable channel is
;     WO2 = PA2, which IS on the header.
;
; PWM behaviour (datasheet 23.3.3.4, single-slope): the counter counts UP from
; 0 to PER; the output is set HIGH at BOTTOM and cleared LOW on the compare
; match.  Duty(high) = CMP2 / (PER + 1).
;
;   F_CPU = 4 MHz, prescaler = 1, PER = 255  ->  PWM = 4 MHz / 256 = 15.625 kHz
;   CMP2  = 63                               ->  duty = 63 / 256  = ~25 %
; =============================================================

#include <avr/io.h>

; ---------- Pin / register aliases ----------
; NOTE: comments on #define lines must use C-style // (or /* */), not ';'.
#define WO2_PIN     2                          // PA2 == TCA0 WO2
#define VPORT_DIR   _SFR_IO_ADDR(VPORTA_DIR)   // PORTA data-direction (low I/O)
#define STACK_LOW   _SFR_IO_ADDR(SPL)
#define STACK_HIGH  _SFR_IO_ADDR(SPH)
#define STATUS      _SFR_IO_ADDR(SREG)

; Microchip's *_gc group constants (e.g. TCA_SINGLE_WGMODE_SINGLESLOPE_gc) are
; C enums in <avr/io.h>, and the device header hides all its enum/struct
; typedefs behind #if !defined(__ASSEMBLER__). So they are invisible to the
; assembler regardless of the avr-gcc/device-header version.
; Only the #define macros survive into assembly (register addresses, *_bm,
; *_bp, *_gp), so build the multi-bit field from its bit position (*_gp) here.
#define WGM_SINGLESLOPE  (0x3 << TCA_SINGLE_WGMODE_gp)  // CTRLB: single-slope PWM

; ---------- PWM parameters ----------
.equ    PER_TOP, 255                    ; TOP -> 256 steps, 15.625 kHz @ 4 MHz
.equ    DC, 75                          ; duty cycle (%)
.equ    CMP_VAL, (DC * (PER_TOP + 1)) / 100   ; compare value for the duty cycle

; -------------------- Interrupt vector table --------------------
; We never enable interrupts, so only vector 0 (RESET) is ever taken.
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler           ; vector 0  RESET

.section .text

reset_handler:                      ; also serves as main_setup
    ldi     r16, hi8(RAMEND)        ; init 16-bit stack pointer
    out     STACK_HIGH, r16
    ldi     r16, lo8(RAMEND)
    out     STACK_LOW, r16
    eor     r1, r1                  ; r1 = GCC __zero_reg__ convention
    out     STATUS, r1              ; clear status register

    ; --- PA2 as output so the WO2 waveform reaches the pin ---
    sbi     VPORT_DIR, WO2_PIN

    ; --- TCA0 normal (16-bit) single-slope PWM on WO2 ---
    ; PER and CMP2 are 16-bit; write the low byte then the high byte.
    ldi     r16, lo8(PER_TOP)
    sts     TCA0_SINGLE_PERL, r16
    ldi     r16, hi8(PER_TOP)
    sts     TCA0_SINGLE_PERH, r16           ; PER = period (sets PWM frequency)

    ldi     r16, lo8(CMP_VAL)
    sts     TCA0_SINGLE_CMP2L, r16
    ldi     r16, hi8(CMP_VAL)
    sts     TCA0_SINGLE_CMP2H, r16          ; CMP2 = duty cycle on WO2

    ldi     r16, WGM_SINGLESLOPE | TCA_SINGLE_CMP2EN_bm
    sts     TCA0_SINGLE_CTRLB, r16          ; single-slope PWM, enable WO2 output

    ldi     r16, TCA_SINGLE_ENABLE_bm       ; CLKSEL = DIV1 (0), ENABLE = 1
    sts     TCA0_SINGLE_CTRLA, r16          ; start the timer

main_loop:
    rjmp    main_loop               ; PWM runs autonomously in hardware

.section .data
.section .bss
