;==============================================================================
;  taskblock.S
;------------------------------------------------------------------------------
;  Copy an initialized 16-byte task_block from Flash (LMA) into SRAM (VMA),
;  then access its fields by name using Y-pointer displacement addressing.
;
;  Demonstrates:
;    - .data section with mixed initialized + zero-filled bytes (.zero)
;    - .set field offsets used as ldd/std displacements (the "struct" pattern)
;    - A hand-rolled __do_copy_data equivalent (bare-metal, -nostartfiles)
;    - Assembly-time size assertion (.if / .error)
;
;  Target : AVR64DD32  (Curiosity Nano)
;  Clock  : n/a (no timing-dependent code)
;  Build  : avr-gcc -nostartfiles -mmcu=avr64dd32 -o task_init.elf task_init_dd32.S
;  Debug  : avr-gdb  (Bloom GDB RSP server @ 127.0.0.1:1442)
;==============================================================================

#include <avr/io.h>

;------------------------------------------------------------------------------
;  Registers and Values
;------------------------------------------------------------------------------
;  r16        : scratch (stack-pointer setup)
;  r18, r19   : task_block SP field, low / high
;  r20        : scratch (status write-back)
;  r24        : copy byte / field reads (status)
;  r25        : copy compare high byte / field reads (priority)
;  X (r26:27) : copy DESTINATION pointer -> SRAM   (__data_start .. __data_end)
;  Y (r28:29) : task_block base pointer (field access via displacement)
;  Z (r30:31) : copy SOURCE pointer     -> Flash  (__data_load_start)
;
;  Task block field offsets (assembly-time constants, zero bytes of storage):
;    TB_STATUS = 0   1 byte   run state
;    TB_PRIO   = 1   1 byte   priority
;    TB_SP     = 2   2 bytes  saved stack pointer (little-endian)
;    TB_STACK  = 4  12 bytes  scratch / saved context (zero-initialized)
;    TB_SIZE   = 16          total block size
;==============================================================================

        .set    TB_STATUS,   0
        .set    TB_PRIO,     1
        .set    TB_SP,       2
        .set    TB_STACK,    4
        .set    TB_SIZE,     16

;==============================================================================
;  SECTION 1 : Vectors
;------------------------------------------------------------------------------
;  Minimal hand-rolled table. Reset vector (address 0) jumps to _start.
;  Unused vectors fall through to a parked reti. Extend as peripherals are
;  enabled (see your main_dd32.S house pattern).
;==============================================================================

        .section .vectors, "ax", @progbits
        .global  __vectors
__vectors:
        rjmp    _start                  ; 0x00  RESET
        reti                            ; 0x02  (unused IRQ - park)
        ; ... add further vectors here as needed ...

;==============================================================================
;  SECTION 2 : Data
;------------------------------------------------------------------------------
;  task_block lives in .data: its initialization image is stored in Flash
;  (load address / LMA) and is copied to SRAM (virtual address / VMA) by the
;  copy_data routine below before main runs.
;==============================================================================

        .section .data
        .global  task_block
task_block:
        .byte   0x01                    ; TB_STATUS
        .byte   0x04                    ; TB_PRIO
        .word   0x21FF                  ; TB_SP   (stored LE: FF 21)
        .zero   12                      ; TB_STACK : 12 zero bytes

        ; Assembly-time guard: actual size must equal declared TB_SIZE.
        ; Break .zero to 11 to watch this stop the build.
        .if     (. - task_block) != TB_SIZE
        .error  "task_block size mismatch"
        .endif

;==============================================================================
;  SECTION 3 : Code
;==============================================================================

        .section .text
        .global  _start
        .global  main

;------------------------------------------------------------------------------
;  _start : entry from RESET vector
;------------------------------------------------------------------------------
_start:
        ;----- Initialize the stack pointer to top of SRAM -----
        ldi     r16, lo8(RAMEND)
        out     CPU_SPL, r16
        ldi     r16, hi8(RAMEND)
        out     CPU_SPH, r16

;------------------------------------------------------------------------------
;  copy_data : Flash (LMA) -> SRAM (VMA)
;    Hand-rolled equivalent of avr-libc's __do_copy_data.
;    X -> SRAM destination, Z -> Flash source.
;    Loop terminates on pointer compare against __data_end (NOT a byte count),
;    so it stays correct if more .data is added later.
;    .data's Flash image sits in low 64 KB on this part, so plain LPM is fine
;    (no RAMPZ / ELPM needed).
;------------------------------------------------------------------------------
copy_data:
        ldi     r26, lo8(__data_start)        ; X -> SRAM dest
        ldi     r27, hi8(__data_start)
        ldi     r30, lo8(__data_load_start)   ; Z -> Flash src
        ldi     r31, hi8(__data_load_start)
copy_loop:
        cpi     r26, lo8(__data_end)          ; X == __data_end ?
        ldi     r25, hi8(__data_end)
        cpc     r27, r25
        breq    copy_done                     ;   yes -> finished
        lpm     r24, Z+                        ; r24 <- Flash[Z], Z++
        st      X+,  r24                       ; SRAM[X] <- r24, X++
        rjmp    copy_loop
copy_done:

;------------------------------------------------------------------------------
;  main : access the now-initialized block by field name
;------------------------------------------------------------------------------
main:
        ldi     r28, lo8(task_block)          ; Y -> block base
        ldi     r29, hi8(task_block)

        ldd     r24, Y+TB_STATUS              ; r24 <- 0x01  (status)
        ldd     r25, Y+TB_PRIO               ; r25 <- 0x04  (priority)
        ldd     r18, Y+TB_SP                  ; r18 <- 0xFF  (SP low)
        ldd     r19, Y+TB_SP+1               ; r19 <- 0x21  (SP high)

        ldi     r20, 0x02
        std     Y+TB_STATUS, r20             ; status <- 0x02

end:
        rjmp    end                           ; park

;==============================================================================
;  End of task_init_dd32.S
;==============================================================================