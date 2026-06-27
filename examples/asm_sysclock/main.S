; =============================================================
; sysclock  –  provides non-blocking 1kHz timer
; Target : AVR64DD32 @4MHz
; Toolchain: avr-gcc  (GNU AVR toolchain)
; =============================================================

#include <avr/io.h>
#include "registers.S"
#include "serial.S"
#include "sysclock.S"

; ====================================================================
;  INTERRUPT VECTOR TABLE
;  AVR64DD32 has 64 KB (32 K words) of flash -- MORE than 8 K words -- so
;  each vector slot is 2 words (4 bytes) and must use JMP, not RJMP. Vector N
;  therefore lives at byte offset N*4 (TCA0_OVF = vector 9 -> 0x24). Using
;  rjmp/reti (2 bytes) here would misplace every vector past reset: reset
;  still works (PC starts at 0), but interrupts would dispatch to the wrong
;  address. Unused slots jmp to 0 (reset) as a bad-interrupt trap.
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
    jmp     TCA0_OVF_handler    ; 0x024  vector 9  TCA0_OVF

; ====================================================================
;  TEXT SECTION  (executable code lives here)
; ====================================================================
.section .text

; ---------- Registers and Values ----------------
; r5:r4                         ; initial ticks count
; r7:r6                         ; final ticks count and delta
; r15                           ; temp register, saved in ISR
; r16                           ; temp register
; char_24                      ; char register (serial)
; delay_hi/lo                   ; delay word
; ---------- Reserved registers ----------
; r2        ISR_2 - ISR scratch (STATUS save) — do NOT use elsewhere
; r9:r8     ticks_9_hi/lo - global 16-bit ISR ticks counter — do NOT use elsewhere

.equ    COUNTER, 30000          ; 30,000 @ 4 MHz => ~30 ms delay (~30 ticks)
                                ; window must span many 1 ms ticks or the
                                ; measured delta reads 0; see sysclock_timing.md
.equ    HEX_BEG, 0xBB           ; beginning of hex print
.equ    HEX_END, 0xEE           ; end of hex print
; --------------------------------------------------------------------
; reset_handler – entry point after RESET
; --------------------------------------------------------------------
reset_handler:

    ; r1 = 0 by convention (zero register); clear status flags
    eor     r1, r1
    out     STATUS, r1

; --------------------------------------------------------------------
; main – delay COUNT times and compare to number of elapsed ticks
;        display the number of elapsed ticks on the serial port
; --------------------------------------------------------------------
main_setup:

    rcall   init_sysclock_1k
    rcall   init_serial

main_loop:
    ldi     char_24, HEX_BEG
    rcall   char_write

    ldi     r27,hi8(COUNTER)
    ldi     r26,lo8(COUNTER)

    ; get ticks start
    movw    r4, ticks_8_lo

delay_1ms:
    sbiw    r26,1
    brne    delay_1ms

    ; get ticks end
    movw    r6, ticks_8_lo

    ; delta ticks = end - start
    sub     r6, r4
    sbc     r7, r5

    ; print delta ticks in hex
    mov     char_24, r7
    rcall   char_write
    mov     char_24, r6
    rcall   char_write

    ldi     char_24,  HEX_END
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
