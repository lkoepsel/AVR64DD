# oneline
Simple table-driven multitasking program. On AVR ucontrollers, `ICALL` calls the routine whose word-address is in the Z register (`r31:r30`). Because Flash addressing on AVR uses word addresses for indirect calls but `LPM` reads bytes, a jump table built in Flash must account for that.

There are three parts required for this approach to work:
1. A **table** of function addresses. The table provides the order of execution as well as the number of times a function will execute.
2. The **functions** are singular tasks which run to completion.
3. **Dispatch** logic proceeds through the table calling each function.

## The Table
A table drives the order of execution of the functions, with the order starting at bottom of the table. The size of the table is automatically calculated at compile-time. The table addresses need to be word addresses (*similar to stack addresses*). Each entry represents an execution of the function at that entry. A function may be called in any order or any number of times.

```asm
; ---- The table: each entry is the WORD address of a task ----
; Entry count, computed by the assembler from the table span.
; pm() converts a byte address into a program-memory word address
; As each entry is a .word (2 bytes), divide the byte length by 2.
; Table execution starts at the bottom, goes to the top.
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
```

## The Functions
Each function is a task which you wish to run. In this example, each task runs to completion then ceeds control back to the dispatch code. A function takes the form of:

```asm
task3:
        ldi     temp_16, 0x3
        out     VPA_OUT, temp_16
        delay_16 time_0
        ret
```
In the above example, the function outputs a value to a set of pins. In this case 0x0c, indicating task 3 is running. After a delay of *time_0*, the function returns control to the dispatch code by a `ret`.

## Dispatch logic
The goal of the dispatch logic is to get the address of the next task to be executed. Due to the intricacies of the AVR assembly language, its a bit of a shell game. The steps are:
1. Get the index of the next task
2. Add the index to the address of the jump table
3. Load the address
4. Call the address

Steps 1 and 2 require using the Z register to load immediate and add the index. Steps 3 and 4 require using the Z register to fetch the address then use it to call the next task. These two sets of steps, require the use of an iterim register r6:r7, to hold the Z register.

## Key Points

`ICALL` uses Z as a *word* address (the Program Counter is word-granular on AVR), while `LPM` reads *bytes* from Flash. That mismatch is the classic source of bugs. The table stores word addresses via `pm(label)` (the avr-gcc/binutils operator that divides a byte address by 2). To fetch the Nth entry with `LPM`, you scale the index by 2 because each `.word` entry occupies 2 bytes in Flash, but the *value* you load is already a word address ready for `ICALL`.

Contrast with `ICALL` vs `CALL`/`RCALL`: the latter two encode a fixed destination at assembly time, so they can't be data-driven. `ICALL` is how you get a C-style function-pointer table or a `switch` jump table in assembly. The cost is 3 cycles on the AVR uC and one extra word of return address on the RAM stack — worth flagging if there are constraints.
