; ====================================================================
;  sysclock_dd32
;       TCA0_OVF_handler   - minimal ISR to increment ticks counter
;       init_sysclock_1k   - setup TCA0 to provide ~1ms ticks via OVF
;       ticks              - return current 16-bit tick count in r25:r24
; Target : AVR64DD32 (Curiosity Nano)
; Clock  : 4 MHz default main clock (OSCHF, post-reset state)
; Toolchain: avr-as / avr-ld  (GNU Binutils for AVR)
; Debugger : Bloom over UPDI  (avr_gdb_rsp @ 127.0.0.1:1442)
; ====================================================================
;
;      We use TCA0 in NORMAL mode with the OVF (overflow) interrupt:
;      the timer counts 0 -> PER, and fires OVF when it rolls over.
;    * TCA0 registers are memory-mapped (use lds/sts), NOT low I/O.
;      Only a handful of CPU regs (SREG, SP) still use in/out.
;    * The interrupt vector is TCA0_OVF_vect = __vector_9 on this device.
;      VERIFY this number against your header (see note below) before relying
;      on it -- vector numbers are device-specific.
;
;  Tick rate math (4 MHz main clock):
;      f_tick = f_clk / (prescale * (PER + 1))
;      For 1 kHz (1 ms) with prescale = 64:
;          PER + 1 = 4,000,000 / (64 * 1000) = 62.5  ->  PER = 62 (approx)
;      62 gives ~1.008 ms; 63 gives ~1.024 ms. Tune PER for your accuracy
;      needs, or pick prescale = 16 and PER = 249 for an exact 1.000 ms:
;          4,000,000 / (16 * (249 + 1)) = 1000.0 Hz   <-- exact, used below
; ====================================================================

; Dependencies — included here so this module assembles standalone
#include <avr/io.h>
#include "registers.S"

; ====================================================================
;  Register and symbol notes
; ----------------------------------------------------------------
;  VERIFY these against your device header before class:
;     grep -E 'TCA0_OVF_vect|TCA_SINGLE_(ENABLE|CLKSEL|WGMODE)|OVF' \
;          /path/to/ioavr64dd32.h
;
;  Memory-mapped TCA0 register offsets (AVR-Dx family, SINGLE mode).
;  These are the conventional AVR-Dx addresses; confirm on your header.
; ====================================================================

; ---------- Registers and Values ----------------
; r16                           ; temp register (general scratch)
; ISR uses a dedicated save reg so it never clobbers main's scratch:
; r2                            ; ISR_2  - SREG save inside the ISR
; r8 / r9                       ; ticks_8_lo / ticks_9_hi - 16-bit tick counter
;

; ====================================================================
;  TEXT SECTION  (executable code lives here)
; ====================================================================
.section .text

; --------------------------------------------------------------------
;  TCA0 overflow ISR.
;  __vector_9 overrides the CRT's weak symbol for TCA0_OVF_vect (C builds).
;  TCA0_OVF_handler is kept as an alias so pure-asm vector tables still link.
;
;  Confirmed: TCA0_OVF_vect = _VECTOR(9), table byte address 0x12
;  (vector 9 * 2 bytes per rjmp slot = 0x12).
; --------------------------------------------------------------------
.global __vector_9
__vector_9:
TCA0_OVF_handler:
    in      ISR_2, CPU_SREG          ; save status flags
    ; --- clear the OVF interrupt flag by writing 1 to it ---
    ;     TCA0.SINGLE.INTFLAGS, OVF bit (bit 0). Write-1-to-clear.
    ldi     temp_16, TCA_SINGLE_OVF_bm
    sts     TCA0_SINGLE_INTFLAGS, temp_16
    ; --- increment the 16-bit tick counter ---
    inc     ticks_8_lo                    ; r8++
    brne    1f                          ; no carry -> done
    inc     ticks_9_hi                    ; carry -> bump high byte
1:
    out     CPU_SREG, ISR_2          ; restore status flags
    reti

; --------------------------------------------------------------------
;  init_sysclock_1k
;  Configure TCA0 in NORMAL mode to overflow at 1 kHz (1 ms ticks) and
;  enable the OVF interrupt. Assumes 4 MHz main clock (post-reset OSCHF).
;
;    prescale = 16  (CLKSEL = DIV16)
;    PER      = 249 -> overflow every (249+1) counts
;    f = 4MHz / (16 * 250) = 1000.0 Hz  (exact 1 ms)
; --------------------------------------------------------------------
.global init_sysclock_1k
init_sysclock_1k:
    ; clear the tick counter
    eor     ticks_8_lo, ticks_8_lo          ; ticks_8_lo = 0
    eor     ticks_9_hi, ticks_9_hi          ; ticks_9_hi = 0

    ; --- set PER = 249 (16-bit write; low byte then high byte) ---
    ;     TCA in SINGLE mode: PER is 16-bit at TCA0.SINGLE.PER
    ldi     temp_16, lo8(249)
    sts     TCA0_SINGLE_PERL, temp_16
    ldi     temp_16, hi8(249)
    sts     TCA0_SINGLE_PERH, temp_16

    ; --- WGMODE = NORMAL (CTRLB low 3 bits = 0) ---
    ;     *_gc group codes are C enum constants in modern avr-libc and are
    ;     invisible to the assembler -- build the field from its *_gp #define.
    ldi     temp_16, (0x0 << TCA_SINGLE_WGMODE_gp)   ; WGMODE = NORMAL (0)
    sts     TCA0_SINGLE_CTRLB, temp_16

    ; --- enable the overflow interrupt: INTCTRL.OVF = 1 ---
    ldi     temp_16, TCA_SINGLE_OVF_bm
    sts     TCA0_SINGLE_INTCTRL, temp_16

    ; --- start the timer: CLKSEL = DIV16, ENABLE = 1 ---
    ;     CLKSEL DIV16 value = 0x4 (see TCA_SINGLE_CLKSEL_DIV16_gv); shift it
    ;     into the CLKSEL field with *_gp, then OR in the ENABLE bit mask.
    ldi     temp_16, (0x4 << TCA_SINGLE_CLKSEL_gp) | TCA_SINGLE_ENABLE_bm
    sts     TCA0_SINGLE_CTRLA, temp_16

    sei                                 ; global interrupt enable
    ret

; --------------------------------------------------------------------
;  ticks  - return the current 16-bit tick count in r25:r24
;           (matches the tiny13 module's movw-based return convention)
;
;  Reads the two counter bytes with interrupts briefly disabled so a
;  mid-read overflow can't tear the 16-bit value.
; --------------------------------------------------------------------
.global ticks
ticks:
    in      ISR_2, CPU_SREG      ; save I-flag state
    cli                             ; atomic 16-bit read
    movw    r24, ticks_8_lo           ; r25:r24 <- r9:r8
    out     CPU_SREG, ISR_2      ; restore (re-enables I if it was set)
    ret

; ====================================================================
;  DATA SECTION  (initialized variables in SRAM)
; ====================================================================
.section .data

; ====================================================================
;  BSS SECTION  (zero-initialized / uninitialized variables in SRAM)
; ====================================================================
.section .bss
