; =============================================================
; ring  –  example serial program, echo's serial input
; Interrupt-driven version of examples/echo: same behaviour, but the
; characters move through the ring buffers in serial_ISR.S instead of
; the polling loops in serial.S. The echo loop below only touches the
; buffers, so the CPU is free between characters -- main_work stands in
; for whatever the application would be doing with that time.
;
; Three things this version needs that the polling version does not:
;   1. #include "serial_ISR.S" instead of "serial.S"
;   2. a vector table long enough to reach USART0_DRE (vector 22)
;   3. sei, after init_serial
;
; to confirm working, ensure local echo is off in serial program
; NOTE: Serial communications requires 4MHz clock
; Target : AVR64DD32 (4MHz default clock)
; Toolchain: avr-gcc  (GNU AVR toolchain)
; =============================================================

#include <avr/io.h>
#include "clocks.S"
#include "registers.S"
#include "serial_ISR.S"

.include "vectors.inc"

; ====================================================================
;  TEXT CONSTANTS SECTION  (Constants for printing lives here)
; ====================================================================
.section .progmem.data

prompt: .asciz  "DD:"

; ====================================================================
;  TEXT SECTION  (executable code lives here)
; ====================================================================
.section .text

; ---------- Registers and Values ----------------
; r16           ; temp register
; r24           ; char register
; Z_31_hi/Z_30_lo       ; address of program text to print

; --------------------------------------------------------------------
; reset_handler – entry point after RESET
; --------------------------------------------------------------------
_start:

    ; r1 = 0 by convention (zero register); clear status flags
    eor     r1, r1
    out     STATUS, r1

    rjmp    main_setup

; --------------------------------------------------------------------
; main – application logic starts here
; --------------------------------------------------------------------
main_setup:
    rcall   set_4M              ; serial comms requires 4M clock
    rcall   init_serial

    sei                         ; init_serial leaves this to us; without
                                ; it neither ISR ever runs and the echo
                                ; loop waits forever

    ; prompt to show terminal is live
    ldi     Z_30_lo, lo8(prompt)
    ldi     Z_31_hi, hi8(prompt)
    rcall   flash_write

; echo loop – char_available lets main keep working between characters,
; which is what the polling version could not do
echo_loop:
    rcall   char_available
    cpi     char_24, 0
    breq    main_work           ; nothing buffered -> go do other work
    rcall   char_read           ; buffered, so this returns immediately
    rcall   char_write          ; queued, so this returns immediately
    rjmp    echo_loop

; stand-in for the application. Characters arriving during this are
; buffered by the RX ISR rather than lost.
main_work:
    rjmp    echo_loop


; ====================================================================
;  DATA SECTION  (initialized variables in SRAM)
;  Declare with:  my_var: .byte 0
; ====================================================================
.section .data

; ====================================================================
;  BSS SECTION  (zero-initialized / uninitialized variables in SRAM)
;  Declare with:  my_buf: .skip 16
; ====================================================================
.section .bss
