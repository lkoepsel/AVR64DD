# oneline_debug
Fundamentally the same program as **oneline**, however, uses an interrupt to write which task is operating. This allows one to debug the sequence and execution time of each task.

In order to view the task execution time, view the `tasks` memory in the debugger. It will appear something like this:

```asm
─── AVR SRAM 
tasks  0x6000..0x607F
  0x6000  04 05 05 05 05 03 02 02 06 06 01 00 04 04 04 04  ................
  0x6010  05 05 05 03 03 02 06 06 01 07 04 04 04 04 05 05  ................
  0x6020  05 03 03 02 06 06 01 07 00 04 04 04 05 05 05 03  ................
  0x6030  03 02 02 06 01 07 00 04 04 04 05 05 05 05 03 02  ................
  0x6040  02 06 06 07 00 04 04 04 04 05 05 05 03 03 02 06  ................
  0x6050  06 01 07 04 04 04 04 05 05 05 03 03 02 06 06 01  ................
  0x6060  07 00 04 04 04 05 05 05 03 03 02 02 06 01 07 00  ................
  0x6070  04 04 04 05 05 05 03 03 02 02 06 01 07 00 04 04  ................
```

The table used to drive this execution is:

```asm
jump_table:
        .word   pm(task7)
        .word   pm(task1)
        .word   pm(task6)
        .word   pm(task2)
        .word   pm(task3)
        .word   pm(task5)
        .word   pm(task4)
        .word   pm(task0)
jump_table_end:
```

along with these task execution times:

| time | tasks |
| ---: | ----: |
| time_0 | 0, 1, 7 |
| time_0 * 2 | 2, 3, 6 |
| time_0 * 4| 4, 5 |

## Summary
The execution order appears correct, as the tasks are being executed 4-5-3-2-6-1-7. The tasks time or ISR time-slicing isn't quite appropriate as several times as task such as task1, isn't represented in the table. By increasing time_0, to 0x0100 from 0x00A0, task1 is represented consistently. Thus its important to ensure the sampling rate by the ISR is sufficient to record all tasks occuring.