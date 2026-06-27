; asm_oneline.S - ICALL jump table demo for AVR64DD32
; uses lpm command to load jump table addr from FLASH

#include <avr/io.h>
#include "registers.S"

; -------------------- Interrupt vector table --------------------
; No interrupts are enabled, only vector 0/RESET can be taken
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler           ; vector 0  RESET

.section .text

; ---------- Registers and Values ----------------
; r4                            ; saved index for jump table
; r7:r6                         ; temp registers for lpm command
; r16                           ; temp register
; r19:r18                       ; delay register
; ---------- Reserved registers ----------
; r2        ISR_2 - ISR scratch (STATUS save) — do NOT use elsewhere
; r9:r8     ticks_9_hi/lo - global 16-bit ISR ticks counter — do NOT use elsewhere

.equ    time_0, 0x0200

        .section .text
        .global  main
reset_handler:

        ; r1 = 0 by convention (zero register); clear status flags
        eor     r1, r1
        out     STATUS, r1

        ldi     temp_16, 0x1c
        out     VPA_DIR, temp_16   ; PA2-4 outputs

reload:
        ; ---- Start at the last table entry and dispatch down to 0 ----
        ldi     temp_16, NUM_TASKS - 1          ; index of last entry (count auto-computed)
        mov     index_4, temp_16            ; r4 = saved index, survives icall
dispatch:
        ; Z = jump_table + (index * 1 word)
        mov     temp_16, index_4            ; working copy of the index
        lsl     temp_16                         ; index * 2 (each entry is 1 word = 2 bytes)
        ldi     ZL, lo8(jump_table)
        ldi     ZH, hi8(jump_table)
        add     ZL, temp_16
        adc     ZH, r1                          ; r1 assumed 0

        ; Load the task's WORD address stored in the table. LPM cannot target
        ; Z_30_lo/Z_31_hi (Z) directly, so read into r7:r6 then movw into Z in one op.
        lpm     r6, Z+
        lpm     r7, Z
        movw    ZL, r6                   ; ZL<-r6 (low), ZH<-r7 (high)
        ; Z holds the word-address of the target task
        icall                             ; push PC, jump to (Z)

        dec     index_4
        brmi    reload
        rjmp    dispatch


; ---- Tasks ----
task0:
        ldi     temp_16, 0x00
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

task1:
        ldi     temp_16, 0x04
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

task2:
        ldi     temp_16, 0x08
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

task3:
        ldi     temp_16, 0x0c
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

task4:
        ldi     temp_16, 0x10
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

task5:
        ldi     temp_16, 0x14
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

task6:
        ldi     temp_16, 0x18
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

task7:
        ldi     temp_16, 0x1c
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret

; ---- The table: each entry is the WORD address of a task ----
; Entry count, computed by the assembler from the table span.
; Each entry is a .word (2 bytes), so divide the byte length by 2.
; Table execution starts at the bottom, goes to the top
        .equ    NUM_TASKS, (jump_table_end - jump_table) / 2

        .balign 2
jump_table:
        .word   pm(task7)
        .word   pm(task6)
        .word   pm(task5)
        .word   pm(task4)
        .word   pm(task3)
        .word   pm(task2)
        .word   pm(task1)
        .word   pm(task0)
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

