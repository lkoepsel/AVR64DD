;==============================================================================
;  functblock.S
;------------------------------------------------------------------------------
;  Function version of taskblock, the "one-line kernel" cooperative multitasker.
;  Stepping stone version to multitasking OS
;
;  An array of MAX_TASKS task blocks drive a pin on/off on its own
;  schedule. The main loop walks the array calling update() on each task;
;  update() compares (now - elapsed time) against the on/off threshold and toggles
;  the pin when the interval expires.
;
;  Task block mirrors this C struct, but with 16-bit timing fields:
;
;      struct TASK {
;          uint8_t  pin;      // output pin number
;          uint8_t  state;    // HIGH or LOW
;          uint16_t on;       // time on   (was uint32_t)
;          uint16_t off;      // time off  (was uint32_t)
;          uint16_t elapsed;  // time of last toggle (was uint32_t)
;      };
;
;  External dependencies (declared .extern, called per AVR ABI):
;    ticks         -> returns elapsed tick count (ms) in r24:r25
;    init_sysclock_1k -> initializes a 1ms clock @4MHz
;
;==============================================================================

#include <avr/io.h>
#include "clocks.S"
#include "io.S"
#include "sysclock.S"
#include "sysclock_b.S"

;------------------------------------------------------------------------------
;  Constants
;------------------------------------------------------------------------------
        .equ    MAX_TASKS, 3
        .equ    DEFAULT_ON,   100
        .equ    DEFAULT_OFF,  100

        .equ    LOW,          0
        .equ    HIGH,         1
        .equ    OUTPUT,       1              

;------------------------------------------------------------------------------
;  Task block field offsets (assembly-time constants; zero storage)
;------------------------------------------------------------------------------
        .equ    PIN,      0     ; 1 byte  output pin number
        .equ    STATE,    1     ; 1 byte  HIGH / LOW
        .equ    ON_TIME,  2     ; 2 bytes time on   (LE word)
        .equ    OFF_TIME, 4     ; 2 bytes time off  (LE word)
        .equ    ELAPSED,  6     ; 2 bytes last-toggle timestamp
        .equ    SPARE,    8     ; 1 byte, spare, TBD
        .equ    TASK_NO,  9     ; 1 byte, ASCII number for task
        .equ    SIZE,     10    ; bytes per task (no padding here)

;==============================================================================
;  Registers and Values
;------------------------------------------------------------------------------
;  Globals / call-saved usage:
;    Y (r28:29) : per-task base pointer inside update()  (call-saved)
;    r17        : loop counter (TASK index) in main    (call-saved)
;
;  update() scratch (caller-saved r18..r27, r30..r31):
;    r24:r25  : now = ticks()  ; also pin arg / field temporaries
;    r22:r23  : threshold (on or off) and digitalWrite level arg
;    r20:r21  : (now - elapsed) difference
;    r18      : state temp
;==============================================================================

;==============================================================================
;  SECTION 1 : Vectors
;==============================================================================

        .section .vectors, "ax", @progbits
        .global  __vectors
__vectors:
.section .vectors, "ax", @progbits
    jmp     _start              ; 0x000  vector 0  RESET
    jmp     bad_interrupt       ; 0x004  vector 1  NMI
    jmp     bad_interrupt       ; 0x008  vector 2  BOD_VLM
    jmp     bad_interrupt       ; 0x00C  vector 3  CLKCTRL
    jmp     bad_interrupt       ; 0x010  vector 4  MVIO_MVIO
    jmp     bad_interrupt       ; 0x014  vector 5  RTC_CNT
    jmp     bad_interrupt       ; 0x018  vector 6  RTC_PIT
    jmp     bad_interrupt       ; 0x01C  vector 7  CCL_CCL
    jmp     bad_interrupt       ; 0x020  vector 8  PORTA_PORT
    jmp     TCA0_OVF_handler    ; 0x024  vector 9  TCA0_OVF
    jmp     bad_interrupt       ; 0x028  vector 10 TCA0_HUNF
    jmp     bad_interrupt       ; 0x02C  vector 11 TCA0_CMP0
    jmp     bad_interrupt       ; 0x030  vector 12 TCA0_CMP1
    jmp     bad_interrupt       ; 0x034  vector 13 TCA0_CMP2
    jmp     TCB0_INT_handler    ; 0x038  vector 14 TCB0_INT 

;==============================================================================
;  SECTION 2 : Data
;------------------------------------------------------------------------------
;  TASKS[MAX_TASKS] : array of task blocks, accessed as TASKS + id*SIZE.
;  Initialized here directly (the C init() runs at startup; doing it as a Flash
;  image + copy means each task is live the moment .data is copied to SRAM).
;
;  Schedules mirror the C main():
;    [0] pin 2, 100 on / 100 off
;    [1] pin 3, 200 on / 200 off   (DEFAULT << 1)
;    [2] pin 4, 400 on / 400 off   (DEFAULT << 2)
;  All start LOW with elapsed = 0.
;==============================================================================

        .section .data
        .global  TASKS
TASKS:
        ; --- task 0 ---
        .byte   2                       ; PIN
        .byte   LOW                     ; STATE
        .word   DEFAULT_ON              ; ON_TIME  = 100
        .word   DEFAULT_OFF             ; OFF_TIME = 100
        .word   0                       ; ELAPSED
        .byte   0xFF                    ; SPARE
        .byte   0x30                    ; TASK_NO
        ; --- task 1 ---
        .byte   3
        .byte   LOW
        .word   DEFAULT_ON  << 1        ; 200
        .word   DEFAULT_OFF << 1        ; 200
        .word   0
        .byte   0xFF                    ; SPARE
        .byte   0x31                    ; TASK_NO
        ; --- task 2 ---
        .byte   4
        .byte   LOW
        .word   DEFAULT_ON  << 2        ; 400
        .word   DEFAULT_OFF << 2        ; 400
        .word   0
        .byte   0xFF                    ; SPARE
        .byte   0x32                    ; TASK_NO

        ; Guard: array must be exactly MAX_TASKS * SIZE bytes.
        .if     (. - TASKS) != (MAX_TASKS * SIZE)
        .error  "TASKS array size mismatch"
        .endif

        .equ    PA_OUT, 0b00011100        ; PA2-4 are output pins 0x1C
;==============================================================================
;  SECTION 3 : Code
;==============================================================================

        .section .text
        .global  _start
        .global  main
        .global  update

;------------------------------------------------------------------------------
;  _start : entry from RESET vector
;------------------------------------------------------------------------------
_start:

;------------------------------------------------------------------------------
;  main
;------------------------------------------------------------------------------
main:
        rcall   copy_data               ; initialize task blocks
        rcall   set_24M                 ; set clock to 24Mhz, a x6 on sys clock
        ; set pins to output
        ldi     temp_16, PA_OUT
        out     VPA_DIR, temp_16        ; set PA2-4 to outputs

        rcall   init_sysclock_1k        ; start the 100 millisecond/6 tick
        rcall   init_sysclock_100u      ; setup ISR to track tasks running
        sei
        rjmp   sched_loop               ; go to scheduler and do not return

; ******************* Functions ***********************************************
;------------------------------------------------------------------------------
;  sched_loop : Table-based scheduler which round-robins the tasks via a table
;    Does not return.
;------------------------------------------------------------------------------
        ;----- One line scheduler - update each task ------------------------
        ; while (1) 
        ;{
        ;       for (i = 0; i < MAX_TASKS; ++i) 
        ;       {
        ;              update(i);
        ;       }
        ;}
.type   sched_loop, @function
sched_loop:
reload:
        ; ---- Start at the last table entry and dispatch down to 0 ----
        ldi     temp_16, NUM_TASKS - 1   ; index of last entry (count auto-computed)
        mov     index_4, temp_16         ; r4 = saved index, survives icall

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

;------------------------------------------------------------------------------
;  copy_data : Flash (LMA) -> SRAM (VMA)  (hand-rolled __do_copy_data)
;    Copies the initialized TASKS[] image into SRAM so the tasks are live.
;------------------------------------------------------------------------------
.type   copy_data, @function
copy_data:
        push    r24
        push    r25
        push    r26
        push    r27
        push    r30
        push    r31

        ldi     tasks_26, lo8(__data_start)        ; X -> SRAM dest
        ldi     tasks_27, hi8(__data_start)
        ldi     Z_30_lo, lo8(__data_load_start)   ; Z -> Flash src
        ldi     Z_31_hi, hi8(__data_load_start)
copy_loop:
        cpi     tasks_26, lo8(__data_end)
        ldi     r25, hi8(__data_end)
        cpc     tasks_27, r25
        breq    copy_done
        lpm     r24, Z+
        st      X+,  r24
        rjmp    copy_loop
copy_done:
        pop     r31
        pop     r30
        pop     r27
        pop     r26
        pop     r24
        pop     r25
        ret
;------------------------------------------------------------------------------
;  update(uint8_t TASKID)   TASKID in r24
;------------------------------------------------------------------------------
;  Computes Y = TASKS + TASKID*SIZE, then replicates the C logic:
;
;    now = ticks();
;    if (state == HIGH && (now - elapsed) >= on)  { state=LOW;  elapsed=now;
;                                                    digitalWrite(pin, LOW);  }
;    else if (state == LOW && (now - elapsed) >= off) { state=HIGH; elapsed=now;
;                                                    digitalWrite(pin, HIGH); }
;
;  All time math is unsigned 16-bit; the (now - elapsed) subtraction wraps
;  correctly modulo 65536, same as the C uint arithmetic.
;------------------------------------------------------------------------------
update:
        push    r28                     ; preserve caller's Y
        push    r29
        push    temp_17                 ; preserve r17

        ;----- now = ticks()  -> r24:r25 --------------------------------------
        ; keep result in r24:r25 throughout
        rcall   ticks                   

        ;----- diff = now - elapsed  -> r20:r21 -------------------------------
        ldd     r20, Y+ELAPSED          ; elapsed low
        ldd     r21, Y+ELAPSED+1        ; elapsed high
        ; diff = now - elapsed
        mov     r18, r24
        mov     r19, r25
        sub     r18, r20
        sbc     r19, r21                ; r19:r18 = now - elapsed

        ;----- branch on current state ----------------------------------------
        ldd     r16, Y+STATE
        cpi     r16, HIGH
        brne    state_is_low

;--- state == HIGH : expire after ON_TIME -------------------------------------
state_is_high:
        ldd     r22, Y+ON_TIME          ; threshold low
        ldd     r23, Y+ON_TIME+1        ; threshold high
        ; if (diff >= on)  i.e. NOT (diff < on)
        cp      r18, r22
        cpc     r19, r23
        brlo    upd_done                ; diff < on -> not yet
        ; --- turn OFF ---
        ldi     r16, LOW
        std     Y+STATE, r16    ; state = LOW
        std     Y+ELAPSED,   r24        ; elapsed = now (low)
        std     Y+ELAPSED+1, r25        ; elapsed = now (high)
        ldd     r24, Y+PIN              ; arg1: pin

        rcall    bitmask                 ; r24 = (1 << pin)
        sts     PORTA_CLR, r24          ; PORTA.OUTSET — turn it off

        rjmp    upd_done

;--- state == LOW : expire after OFF_TIME ---
state_is_low:
        ldd     r22, Y+OFF_TIME         ; threshold low
        ldd     r23, Y+OFF_TIME+1       ; threshold high
        cp      r18, r22
        cpc     r19, r23
        brlo    upd_done                ; diff < off -> not yet
        ; --- turn ON ---
        ldi     r16, HIGH
        std     Y+STATE, r16            ; state = HIGH
        std     Y+ELAPSED,   r24        ; elapsed = now (low)
        std     Y+ELAPSED+1, r25        ; elapsed = now (high)
        ldd     r24, Y+PIN              ; arg1: pin
        rcall    bitmask                 ; r24 = (1 << pin)
        sts     PORTA_SET, r24          ; PORTA.OUTSET — turn it on

upd_done:
        pop     temp_17
        pop     r29
        pop     r28
        ret

;----- get task block ---------------------------------------------------------
        ;----- Y = TASKS + TASKID * SIZE --------------------------------------
        ; use mul to determine index-> index (r24) * SIZE r17 = r0:r1
get_block:
        ;----- get next task block for execution ------------------------------
        ldi     temp_17, SIZE
        mul     r24, temp_17
        movw    Z_30_lo, r0             ; r30:r31 nth taskblock
        eor     r1,r1                   ; set r1 back to 0

        ldi     r28, lo8(TASKS)
        ldi     r29, hi8(TASKS)
        add     r28, Z_30_lo            ; Y = TASKS + nth task offset
        adc     r29, Z_31_hi            ; Y now contains task pointer
        ret

task0:
        .equ    t0, 0
        ldi     r24, t0
        rcall   get_block
        rcall   update        
        ; ldi     task_21, t0
        ; mov     out_5, task_21
        ; out     VPA_OUT, out_5
        ; delay_16 time_0
        ; rcall   ticks
        ; rcall   word_write
        ret
task1:
        .equ    t1, 1
        ldi     r24, t1
        rcall   get_block        
        rcall   update
        ; ldi     task_21, t1
        ; mov     out_5, task_21
        ; lsl     out_5
        ; lsl     out_5
        ; out     VPA_OUT, out_5
        ; delay_16 time_0
        ret

task2:
        .equ    t2, 2  
        ldi     r24, t2
        rcall   get_block        
        rcall   update
        ; ldi     task_21, t2
        ; mov     out_5, task_21
        ; lsl     out_5
        ; lsl     out_5
        ; out     VPA_OUT, out_5
        ; delay_16 time_0
        ret

; ---- The table: each entry is the WORD address of a task ----
; Entry count, computed by the assembler from the table span.
; Each entry is a .word (2 bytes), so divide the byte length by 2.
; Table execution starts at the bottom, goes to the top
        .equ    NUM_TASKS, (jump_table_end - jump_table) / 2

        .balign 2
jump_table:
        .word   pm(task2)
        .word   pm(task1)
        .word   pm(task0)
        ; .word   pm(task2)
        ; .word   pm(task1)
        ; .word   pm(task0)
jump_table_end:

;==============================================================================
;  End of functblock.S
;==============================================================================
