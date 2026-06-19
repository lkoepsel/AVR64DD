; =============================================================
; main  –  Hardware PWM on the user LED using Timer/Counter A (TCA0)
; Target : AVR64DD32 @ 4 MHz   (factory default: internal OSCHF, no prescale)
; Board  : AVR64DD32 Curiosity Nano — LED0 is wired to PF5
; Build  : freestanding (-nostartfiles -nostdlib). This file owns the
;          interrupt vector table and the reset/setup code; there is no
;          C runtime to do it for us.
;
; This is the AVR-Dx port of the ATtiny13A asm_blink_pwm example, which used
; the 8-bit TC0 in Fast-PWM mode on OC0A. The modern AVR-Dx has no TC0; PWM
; comes from the 16-bit Timer/Counter type A (TCA0).
;
; Why Split mode:
;   * TCA0's waveform outputs WO0..WO5 map to pins 0..5 of one port.
;   * LED0 is on PF5, i.e. pin 5 — only reachable as WO5.
;   * In 16-bit (Normal) mode TCA0 has just three channels, WO0..WO2.
;     WO3..WO5 only exist in SPLIT mode, where TCA0 becomes two 8-bit
;     timers: the LOW timer drives WO0..2, the HIGH timer drives WO3..5.
;   * So PF5 == WO5 == the HIGH timer's compare channel 2 (HCMP2).
;
; PWM polarity (AVR64DD32 datasheet 23.3.3.6, Fig 23-15): in Split mode the
; timer counts DOWN; the output is cleared at BOTTOM and set on the compare
; match. Duty(high) = HCMP2 / (HPER + 1). So duty rises with HCMP2, the same
; direction as the ATtiny's OCR0A — the DC_FACTOR formula carries over.
;
;   F_CPU = 4 MHz, prescaler = 1, HPER = 255  ->  PWM = 4 MHz / 256 = 15.6 kHz
;
; NOTE on brightness: LED0 is ACTIVE-LOW (driving PF5 to GND lights it). DC
; below is the duty cycle of the electrical HIGH time on PF5, so the LED is
; lit for the complementary (100 - DC)%. Treat DC as "PWM high duty," not
; "LED brightness." (To make DC mean brightness, set the INVEN bit in
; PORTF.PIN5CTRL so the pin output is inverted.)
; =============================================================

#include <avr/io.h>

; ---------- Pin / register aliases ----------
; NOTE: comments on #define lines must use C-style // (or /* */), not ';'.
#define LED         5                          // PF5 == LED0 == TCA0 WO5
#define VPORT_DIR   _SFR_IO_ADDR(VPORTF_DIR)   // PORTF data-direction (low I/O)
#define STACK_LOW   _SFR_IO_ADDR(SPL)
#define STACK_HIGH  _SFR_IO_ADDR(SPH)
#define STATUS      _SFR_IO_ADDR(SREG)

; The stock avr-gcc <avr/io.h> for the AVR-Dx omits Microchip's *_gc group
; constants (those ship in the DFP pack), so build the multi-bit field values
; from the documented bit positions instead.
#define TCA0_ROUTE_PORTF  (0x5 << PORTMUX_TCA0_gp)    // TCAROUTEA: TCA0 -> PORTF
#define TCA_CLKSEL_DIV1   (0x0 << TCA_SPLIT_CLKSEL_gp) // CTRLA: prescaler /1

; ---------- PWM parameters ----------
.equ    DC, 25                          ; duty cycle of PF5 high time (%)
.equ    HPER_TOP, 255                   ; TOP -> 256 PWM steps
.equ    DC_FACTOR, (DC * HPER_TOP) / 100  ; HCMP2 value for the duty cycle

; -------------------- Interrupt vector table --------------------
; On a >8 KB-flash AVR-Dx each vector entry is a 2-word JMP. We never enable
; interrupts (the global I-bit stays clear after reset), so only vector 0 —
; RESET — is ever taken. The linker places .vectors at 0x0000.
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

    ; --- Route TCA0 waveform outputs to PORTF (WO0..5 -> PF0..5) ---
    ; PORTMUX lives in extended I/O, so use sts/ldi (not out).
    ldi     r16, TCA0_ROUTE_PORTF
    sts     PORTMUX_TCAROUTEA, r16

    ; --- PF5 as output so the WO5 waveform reaches the pin ---
    sbi     VPORT_DIR, LED

    ; --- Configure TCA0 for Split-mode single-slope PWM on WO5 ---
    ; Datasheet 23.3.3.6 init order: SPLITM, then TOP, then ENABLE.
    ldi     r16, TCA_SPLIT_SPLITM_bm
    sts     TCA0_SPLIT_CTRLD, r16           ; enter Split mode

    ldi     r16, HPER_TOP
    sts     TCA0_SPLIT_HPER, r16            ; high-timer TOP -> PWM frequency

    ldi     r16, DC_FACTOR
    sts     TCA0_SPLIT_HCMP2, r16           ; high-timer CMP2 -> duty cycle

    ldi     r16, TCA_SPLIT_HCMP2EN_bm
    sts     TCA0_SPLIT_CTRLB, r16           ; enable WO5 (HCMP2) output

    ldi     r16, TCA_CLKSEL_DIV1 | TCA_SPLIT_ENABLE_bm
    sts     TCA0_SPLIT_CTRLA, r16           ; prescaler /1 + start timer

main_loop:
    rjmp    main_loop               ; PWM runs autonomously in hardware

.section .data
.section .bss
