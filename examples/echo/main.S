; =============================================================
; echo  –  example serial program, echo's serial input
; to confirm working, ensure local echo is off in serial program
; Target : AVR64DD32 (4MHz default clock)
; Toolchain: avr-gcc  (GNU AVR toolchain)
; =============================================================

#include <avr/io.h>
#include "registers.S"
#include "serial.S"

; ====================================================================
;  INTERRUPT VECTOR TABLE
; ====================================================================
.section .vectors, "ax", @progbits
    jmp     reset_handler       ; 0x000  vector 0  RESET
    jmp     0                   ; 0x004  vector 1  NMI
    jmp     0                   ; 0x008  vector 2  BOD_VLM
    jmp     0                   ; 0x00C  vector 3  CLKCTRL
    jmp     0                   ; 0x010  vector 4  MVIO_MVIO
    jmp     0                   ; 0x014  vector 5  RTC_CNT
    jmp     0                   ; 0x018  vector 6  RTC_PIT
    jmp     0                   ; 0x01C  vector 7  CCL_CCL
    jmp     0                   ; 0x020  vector 8  PORTA_PORT
    jmp     0                   ; 0x024  vector 9  TCA0_OVF

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
reset_handler:

    ; r1 = 0 by convention (zero register); clear status flags
    eor     r1, r1
    out     STATUS, r1

    rjmp    main_setup

; --------------------------------------------------------------------
; main – application logic starts here
; --------------------------------------------------------------------
main_setup:

    rcall   init_serial

    ; prompt to show terminal is live
    ldi     Z_30_lo, lo8(prompt)
    ldi     Z_31_hi, hi8(prompt)
    rcall   flash_write

; simple echo loop to test read/write char
main_loop:
    rcall   char_read
    rcall   char_write
    rjmp    main_loop


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
