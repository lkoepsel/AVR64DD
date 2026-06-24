On AVR ucontrollers, `ICALL` calls the routine whose word-address is in the Z register (`r31:r30`). Because Flash addressing on AVR uses word addresses for indirect calls but `LPM` reads bytes, a jump table built in Flash must account for that.

Working example: a jump table of routines, indexed at runtime.

```asm
initialization code
...
jump:
        ; Z = jump_table + (index * 1 word)
        ldi     ZL, lo8(jump_table)
        ldi     ZH, hi8(jump_table)
        ; add index*2 BYTES to the byte pointer used by LPM...
        lsl     r24                       ; index * 2 (each entry is 1 word = 2 bytes)
        add     ZL, r24
        adc     ZH, r1                    ; r1 assumed 0; clr it if unsure

        ; Load the routine's WORD address stored in the table
        lpm     r30, Z+                   ; low byte
        lpm     r31, Z                    ; high byte
        ; Z now holds the word-address of the target routine
        icall                             ; push PC, jump to (Z)

        rjmp    jump_done

jump_done:
        rjmp    jump_done

; ---- The routines ----
routine0:
        ldi     r16, 0x01
        out     _SFR_IO_ADDR(PORTB), r16
        ret

routine1:
        ldi     r16, 0x02
        out     _SFR_IO_ADDR(PORTB), r16
        ret

routine2:
        ldi     r16, 0x04
        out     _SFR_IO_ADDR(PORTB), r16
        ret

; ---- The table: each entry is the WORD address of a routine ----
        .balign 2
jump_table:
        .word   pm(routine0)
        .word   pm(routine1)
        .word   pm(routine2)
```

The key points for your students:

`ICALL` uses Z as a *word* address (the Program Counter is word-granular on AVR), while `LPM` reads *bytes* from Flash. That mismatch is the classic source of bugs. The table stores word addresses via `pm(label)` (the avr-gcc/binutils operator that divides a byte address by 2). To fetch the Nth entry with `LPM`, you scale the index by 2 because each `.word` entry occupies 2 bytes in Flash, but the *value* you load is already a word address ready for `ICALL`.

Contrast with `ICALL` vs `CALL`/`RCALL`: the latter two encode a fixed destination at assembly time, so they can't be data-driven. `ICALL` is how you get a C-style function-pointer table or a `switch` jump table in assembly. The cost is 3 cycles on the AVR uC and one extra word of return address on the RAM stack — worth flagging if there are constraints.

One caution worth giving students: `r1` is the conventional "zero register" under the avr-gcc ABI, but in `-nostdlib` hand-written code nothing guarantees it's zero. If you didn't `clr r1` at startup, use `clr` on a scratch register for the `adc` instead.