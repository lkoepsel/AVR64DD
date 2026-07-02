;==============================================================================
;  multitask_dd32.S
;------------------------------------------------------------------------------
;  Assembly version of the "one-line kernel" cooperative multitasker.
;  Port of main.c (Adafruit "Classy" multitasking, C-struct form).
;
;  An array of MAX_FLASHERS task blocks each drive a pin on/off on its own
;  schedule. The main loop walks the array calling update() on each task;
;  update() compares (now - elapsed) against the on/off threshold and toggles
;  the pin when the interval expires.
;
;  Task block mirrors this C struct, but with 16-bit timing fields
;  (C used uint32_t; 16-bit ms gives ~65 s range, ample for a blinker and
;   keeps the arithmetic to single ADD/SUB/CP pairs):
;
;      struct flasher {
;          uint8_t  pin;      // output pin number
;          uint8_t  state;    // HIGH or LOW
;          uint16_t on;       // time on   (was uint32_t)
;          uint16_t off;      // time off  (was uint32_t)
;          uint16_t elapsed;  // time of last toggle (was uint32_t)
;      };
;
;  External dependencies (declared .extern, called per AVR ABI):
;    ticks         -> returns elapsed tick count (ms) in r24:r25
;    init_sysclock_2
;    pinMode       (pin in r24, dir in r22)
;    digitalWrite  (pin in r24, level in r22)
;
;  Target : AVR64DD32  (Curiosity Nano)
;  Build  : avr-gcc -nostartfiles -mmcu=avr64dd32 -o multitask.elf \
;             multitask_dd32.S ticks.S sysclock.S pinMode.S digitalWrite.S
;  Debug  : avr-gdb  (Bloom GDB RSP server @ 127.0.0.1:1442)
;==============================================================================

#include <avr/io.h>
#include "sysclock.S"

;------------------------------------------------------------------------------
;  Constants
;------------------------------------------------------------------------------
        .set    MAX_FLASHERS, 3
        .set    DEFAULT_ON,   100
        .set    DEFAULT_OFF,  100

        .set    LOW,          0
        .set    HIGH,         1
        .set    OUTPUT,       1               ; match pinMode() convention

;------------------------------------------------------------------------------
;  Task block field offsets (assembly-time constants; zero storage)
;------------------------------------------------------------------------------
        .set    PIN,      0                   ; 1 byte  output pin number
        .set    STATE,    1                   ; 1 byte  HIGH / LOW
        .set    ON_TIME,  2                   ; 2 bytes time on   (LE word)
        .set    OFF_TIME, 4                   ; 2 bytes time off  (LE word)
        .set    ELAPSED,  6                   ; 2 bytes last-toggle timestamp
        .set    SIZE,     8                   ; bytes per task (no padding here)

;==============================================================================
;  Registers and Values
;------------------------------------------------------------------------------
;  Globals / call-saved usage:
;    Y (r28:29) : per-task base pointer inside update()  (call-saved)
;    r17        : loop counter (flasher index) in main    (call-saved)
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
        rjmp    _start                  ; 0x00  RESET
        reti                            ; 0x02  (unused IRQ - park)

;==============================================================================
;  SECTION 2 : Data
;------------------------------------------------------------------------------
;  flashers[MAX_FLASHERS] : array of task blocks, accessed as flashers + id*SIZE.
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
        .global  flashers
flashers:
        ; --- task 0 ---
        .byte   2                       ; PIN
        .byte   LOW                     ; STATE
        .word   DEFAULT_ON              ; ON_TIME  = 100
        .word   DEFAULT_OFF             ; OFF_TIME = 100
        .word   0                       ; ELAPSED
        ; --- task 1 ---
        .byte   3
        .byte   LOW
        .word   DEFAULT_ON  << 1        ; 200
        .word   DEFAULT_OFF << 1        ; 200
        .word   0
        ; --- task 2 ---
        .byte   4
        .byte   LOW
        .word   DEFAULT_ON  << 2        ; 400
        .word   DEFAULT_OFF << 2        ; 400
        .word   0

        ; Guard: array must be exactly MAX_FLASHERS * SIZE bytes.
        .if     (. - flashers) != (MAX_FLASHERS * SIZE)
        .error  "flashers array size mismatch"
        .endif

        .equ    PA_OUT, 0b00011100        ; PA2-4 are output pins 0x1C
;==============================================================================
;  SECTION 3 : Code
;==============================================================================

        .section .text
        .global  _start
        .global  main
        .global  update

        .extern  ticks
        .extern  init_sysclock_2
        .extern  digitalWrite

;------------------------------------------------------------------------------
;  _start : entry from RESET vector
;------------------------------------------------------------------------------
_start:

;------------------------------------------------------------------------------
;  copy_data : Flash (LMA) -> SRAM (VMA)  (hand-rolled __do_copy_data)
;    Copies the initialized flashers[] image into SRAM so the tasks are live.
;------------------------------------------------------------------------------
copy_data:
        ldi     r26, lo8(__data_start)        ; X -> SRAM dest
        ldi     r27, hi8(__data_start)
        ldi     r30, lo8(__data_load_start)   ; Z -> Flash src
        ldi     r31, hi8(__data_load_start)
copy_loop:
        cpi     r26, lo8(__data_end)
        ldi     r25, hi8(__data_end)
        cpc     r27, r25
        breq    copy_done
        lpm     r24, Z+
        st      X+,  r24
        rjmp    copy_loop
copy_done:

;------------------------------------------------------------------------------
;  main
;------------------------------------------------------------------------------
main:
        ; set pins to output
        ldi     temp_16, PA_OUT
        out     VPA_DIR, temp_16                ; PA2-4 outputs

        rcall   init_sysclock_1k               ; start the millisecond tick

        ;----- Scheduler: forever, update each task ------------------------
        ; while (1) for (i = 0; i < MAX_FLASHERS; ++i) update(i);
sched_loop:
        ldi     r17, 0                        ; flasher index
upd_next:
        mov     r24, r17                      ; arg: flasherID
        push    r17
        rcall   update
        pop     r17
        inc     r17
        cpi     r17, MAX_FLASHERS
        brlo    upd_next
        rjmp    sched_loop

;------------------------------------------------------------------------------
;  update(uint8_t flasherID)   flasherID in r24
;------------------------------------------------------------------------------
;  Computes Y = flashers + flasherID*SIZE, then replicates the C logic:
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
        push    r28                           ; preserve caller's Y
        push    r29
        push    r17

        ;----- Y = flashers + flasherID * SIZE -----------------------------
        ; SIZE == 8, so index*8 = index << 3.
        mov     r30, r24                      ; r30 = flasherID
        ldi     r31, 0
        lsl     r30                           ; *2
        rol     r31
        lsl     r30                           ; *4
        rol     r31
        lsl     r30                           ; *8
        rol     r31                           ; r31:r30 = flasherID*SIZE
        ldi     r28, lo8(flashers)
        ldi     r29, hi8(flashers)
        add     r28, r30                      ; Y = flashers + offset
        adc     r29, r31

        ;----- now = ticks()  -> r24:r25 -----------------------------------
        rcall   ticks                         ; r24:r25 = now
        ; keep now in r24:r25 throughout

        ;----- diff = now - elapsed  -> r20:r21 ----------------------------
        ldd     r20, Y+ELAPSED                ; elapsed low
        ldd     r21, Y+ELAPSED+1              ; elapsed high
        ; diff = now - elapsed
        mov     r18, r24
        mov     r19, r25
        sub     r18, r20
        sbc     r19, r21                      ; r19:r18 = now - elapsed

        ;----- branch on current state -------------------------------------
        ldd     r16, Y+STATE
        cpi     r16, HIGH
        brne    state_is_low

;--- state == HIGH : expire after ON_TIME ---
        ldd     r22, Y+ON_TIME               ; threshold low
        ldd     r23, Y+ON_TIME+1             ; threshold high
        ; if (diff >= on)  i.e. NOT (diff < on)
        cp      r18, r22
        cpc     r19, r23
        brlo    upd_done                      ; diff < on -> not yet
        ; --- turn OFF ---
        ldi     r16, LOW
        std     Y+STATE, r16                 ; state = LOW
        std     Y+ELAPSED,   r24             ; elapsed = now (low)
        std     Y+ELAPSED+1, r25             ; elapsed = now (high)
        ldd     r24, Y+PIN                    ; arg1: pin
        ldi     r22, LOW                     ; arg2: level
        rcall   digitalWrite
        rjmp    upd_done

;--- state == LOW : expire after OFF_TIME ---
state_is_low:
        ldd     r22, Y+OFF_TIME              ; threshold low
        ldd     r23, Y+OFF_TIME+1            ; threshold high
        cp      r18, r22
        cpc     r19, r23
        brlo    upd_done                      ; diff < off -> not yet
        ; --- turn ON ---
        ldi     r16, HIGH
        std     Y+STATE, r16                 ; state = HIGH
        std     Y+ELAPSED,   r24             ; elapsed = now (low)
        std     Y+ELAPSED+1, r25             ; elapsed = now (high)
        ldd     r24, Y+PIN                    ; arg1: pin
        ldi     r22, HIGH                    ; arg2: level
        rcall   digitalWrite

upd_done:
        pop     r17
        pop     r29
        pop     r28
        ret

;==============================================================================
;  End of multitask_dd32.S
;==============================================================================
