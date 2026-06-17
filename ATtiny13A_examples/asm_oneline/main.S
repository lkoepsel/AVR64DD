; dispatch.S - ICALL jump table demo for ATtiny13A
; avr-gcc -mmcu=attiny13a -nostdlib -o dispatch.elf dispatch.S

#include <avr/io.h>
#include "registers.S"

; ====================================================================
;  INTERRUPT VECTOR TABLE
;  ATtiny13A has 10 vectors, each one instruction word (2 bytes) wide.
;  Must live at flash address 0x0000.
; ====================================================================
.section .vectors, "ax", @progbits
    rjmp    reset_handler       ; 0x000  RESET
    reti                        ; 0x001  INT0       - External Interrupt 0
    reti                        ; 0x002  PCINT0     - Pin Change Interrupt 0
    reti                        ; 0x003  TIM0_OVF   - Timer/Counter0 Overflow
    reti                        ; 0x004  EE_RDY     - EEPROM Ready
    reti                        ; 0x005  ANA_COMP   - Analog Comparator
    reti                        ; 0x006  TIM0_COMPA - Timer0 Compare Match A
    reti                        ; 0x007  TIM0_COMPB - Timer0 Compare Match B
    reti                        ; 0x008  WDT        - Watchdog Time-out
    reti                        ; 0x009  ADC        - ADC Conversion Complete

; ====================================================================
;  TEXT SECTION  (executable code lives here)
; ====================================================================
.section .text

; ---------- Registers and Values ----------------
; r4                            ; saved index
; r7:r6                         ; temp registers for lpm command
; r16                           ; temp register
; r19:r18                       ; ticks register
; ---------- Reserved registers ----------
; r2        ISR_temp - ISR scratch (STATUS save) — do NOT use elsewhere
; r9:r8     ticks_hi/lo - global 16-bit ISR ticks counter — do NOT use elsewhere

#define  saved_index    r4

; ---- Vector table ----
        .section .text
        .global  main
reset_handler:

        ; ATtiny13A has only SPL (no SPH) — RAMEND = 0x9F fits in 8 bits
        ldi     temp_16, lo8(RAMEND)
        out     STACK_LOW, temp_16

        ; r1 = 0 by convention (zero register); clear status flags
        eor     r1, r1
        out     STATUS, r1

        ldi     temp_16, 0x07
        out     IO_DDR, temp_16   ; PB0-2 outputs

reload:
        ; ---- Start at the last table entry and dispatch down to 0 ----
        ldi     temp_16, NUM_TASKS - 1          ; index of last entry (count auto-computed)
        mov     saved_index, temp_16            ; r4 = saved index, survives icall
dispatch:
        ; Z = jump_table + (index * 1 word)
        mov     temp_16, saved_index            ; working copy of the index
        lsl     temp_16                         ; index * 2 (each entry is 1 word = 2 bytes)
        ldi     ZL, lo8(jump_table)
        ldi     ZH, hi8(jump_table)
        add     ZL, temp_16
        adc     ZH, r1                          ; r1 assumed 0

        ; Load the task's WORD address stored in the table. LPM cannot target
        ; r30/r31 (Z) directly, so read into r7:r6 then movw into Z in one op.
        lpm     r6, Z+
        lpm     r7, Z
        movw    ZL, r6                   ; ZL<-r6 (low), ZH<-r7 (high)
        ; Z holds the word-address of the target task
        icall                             ; push PC, jump to (Z)

        dec     saved_index
        brmi    reload
        rjmp    dispatch


; ---- Tasks ----
task0:
        ldi     temp_16, 0x00
        out     IO_PORT, temp_16
        ; delay_16 0x1000
        ret

task1:
        ldi     temp_16, 0x01
        out     IO_PORT, temp_16
        ; delay_16 0x800
        ret

task2:
        ldi     temp_16, 0x02
        out     IO_PORT, temp_16
        ; delay_16 0x600
        ret

task3:
        ldi     temp_16, 0x03
        out     IO_PORT, temp_16
        ; delay_16 0x800
        ret

task4:
        ldi     temp_16, 0x04
        out     IO_PORT, temp_16
        ; delay_16 0x400
        ret

task5:
        ldi     temp_16, 0x05
        out     IO_PORT, temp_16
        ; delay_16 0x200
        ret

task6:
        ldi     temp_16, 0x06
        out     IO_PORT, temp_16
        ; delay_16 0x500
        ret

task7:
        ldi     temp_16, 0x07
        out     IO_PORT, temp_16
        ; delay_16 0x1000
        ret

; ---- The table: each entry is the WORD address of a task ----
; Entry count, computed by the assembler from the table span.
; Each entry is a .word (2 bytes), so divide the byte length by 2.
        .equ    NUM_TASKS, (jump_table_end - jump_table) / 2

        .balign 2
jump_table:
        .word   pm(task0)
        .word   pm(task5)
        .word   pm(task1)
        .word   pm(task3)
        .word   pm(task7)
        .word   pm(task4)
        .word   pm(task0)
        .word   pm(task6)
        .word   pm(task2)
        .word   pm(task1)
        .word   pm(task3)
        .word   pm(task4)
        .word   pm(task6)
jump_table_end:

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

