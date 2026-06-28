; asm_oneline_mt.S - ICALL jump table demo for AVR64DD32
; uses lpm command to load jump table addr from FLASH
; uses an 100us ISR to write task number to SRAM
; uses an 25ms ISR to write ticks to console
; Use to develop a non-blocking multitasking program

#include <avr/io.h>
#include "clocks.S"
#include "registers.S"
#include "sysclock.S"
#include "sysclock_b.S"
#include "serial.S"

; -------------------- Interrupt vector table --------------------
.section .vectors, "ax", @progbits
.global __vectors
__vectors:
    jmp     reset_handler       ; 0x000  vector 0  RESET
    jmp     0                   ; 0x004  vector 1  NMI
    jmp     0                   ; 0x008  vector 2  BOD_VLM
    jmp     0                   ; 0x00C  vector 3  CLKCTRL
    jmp     0                   ; 0x010  vector 4  MVIO_MVIO
    jmp     0                   ; 0x014  vector 5  RTC_CNT
    jmp     0                   ; 0x018  vector 6  RTC_PIT
    jmp     0                   ; 0x01C  vector 7  CCL_CCL
    jmp     0                   ; 0x020  vector 8  PORTA_PORT
    jmp     TCA0_OVF_handler    ; 0x024  vector 9  TCA0_OVF
    jmp     0                   ; 0x028  vector 10 TCA0_HUNF
    jmp     0                   ; 0x02C  vector 11 TCA0_CMP0
    jmp     0                   ; 0x030  vector 12 TCA0_CMP1
    jmp     0                   ; 0x034  vector 13 TCA0_CMP2
    jmp     TCB0_INT_handler    ; 0x038  vector 14 TCB0_INT 

.section .text

; ---------- Registers and Values (includes ISR) --------------
; r4                            ; saved index for jump table
; r7:r6                         ; temp registers for lpm command
; r16                           ; temp register
; r17                           ; temp register
; r19:r18                       ; delay register
; r20                           ; temp register in task
; r21                           ; tracks executing task
; r27:r26 (X)                   ; pointer to SRAM tasks buffer
; ---------- Reserved registers ----------
; r2        ISR_2 - ISR scratch (STATUS save) — do NOT use elsewhere

.equ    time_0, 0x0100              ; time per task, 4*256*62.5ns = 64ms

        .section .text
        .global  main
reset_handler:

        ; r1 = 0 by convention (zero register); clear status flags
        eor     r1, r1
        out     STATUS, r1

        ldi     temp_16, 0x1c
        out     VPA_DIR, temp_16        ; PA2-4 outputs

        ; rcall   set_16M                 ; 16Mhz clock, 62.5ns clock cycle
        ; rcall   init_sysclock_100u      ; setup ISR to track tasks running
        rcall   init_sysclock_4k        ; setup ISR for task timing
        ; rcall   init_serial             ; setup serial console
reload:
        ; ---- Start at the last table entry and dispatch down to 0 ----
        ldi     temp_16, NUM_TASKS - 1          ; index of last entry (count auto-computed)
        mov     index_4, temp_16            ; r4 = saved index, survives icall
dispatch:
        ; Z = jump_table + (index * 1 word)
        mov     temp_16, index_4        ; working copy of the index
        lsl     temp_16                 ; index * 2 (each entry is 1 word = 2 bytes)
        ldi     ZL, lo8(jump_table)
        ldi     ZH, hi8(jump_table)
        add     ZL, temp_16
        adc     ZH, r1                  ; r1 assumed 0

        ; Load the task's WORD address stored in the table. LPM cannot target
        ; Z_30_lo/Z_31_hi (Z) directly, so read into r7:r6 then movw into Z in one op.
        lpm     temp_6, Z+
        lpm     temp_7, Z
        movw    ZL, temp_6                  ; ZL<-r6 (low), ZH<-r7 (high)
        ; Z holds the word-address of the target task
        icall                             ; push PC, jump to (Z)

        dec     index_4
        brmi    reload
        rjmp    dispatch


; ---- Tasks ----
task0:
        ldi     task_21, 0x00
        out     VPA_OUT, out_5
        delay_16 time_0
        rcall   ticks
        rcall   word_write
        ret

task1:
        ldi     task_21, 0x01
        mov     out_5, task_21
        lsl     out_5
        lsl     out_5
        out     VPA_OUT, out_5
        delay_16 time_0
        ret

task2:
        ldi     task_21, 0x02
        mov     out_5, task_21
        lsl     out_5
        lsl     out_5
        out     VPA_OUT, out_5
        delay_16 time_0
        ret

task3:
        ldi     task_21, 0x03
        mov     out_5, task_21
        lsl     out_5
        lsl     out_5
        out     VPA_OUT, out_5
        delay_16 time_0
        ret

task4:
        ldi     task_21, 0x4
        mov     out_5, task_21
        lsl     out_5
        lsl     out_5
        out     VPA_OUT, out_5
        delay_16 time_0
        ret

task5:
        ldi     task_21, 0x5
        mov     out_5, task_21
        lsl     out_5
        lsl     out_5
        out     VPA_OUT, out_5
        delay_16 time_0
        ret

task6:
        ldi     task_21, 0x6
        mov     out_5, task_21
        lsl     out_5
        lsl     out_5
        out     VPA_OUT, out_5
        delay_16 time_0
        ret

task7:
        ldi     task_21, 0x7
        mov     out_5, task_21
        lsl     out_5
        lsl     out_5
        out     VPA_OUT, out_5
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

