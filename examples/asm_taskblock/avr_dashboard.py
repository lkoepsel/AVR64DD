# Per-example gdb-dashboard register selection for asm_blink.
# Read by ~/.gdbinit.d/avr_modules.py when avr-gdb starts in this directory,
# overriding the module defaults. See docs/gdb-dashboard.md.

# Working registers to show, in display order. asm_blink's delay loop uses the
# temporaries r18/r19/r20 (temp_18 / temp_19 / temp_20 in Library/registers.S).
AVR_REG_SET = ["r16", "r18", "r19", "r20", "r24", "r25"]

# 16-bit pointer pairs to show as one combined value: (low, high, label).
AVR_REG_PAIRS = [("r26", "r27", "X"),("r28", "r29", "Y"),("r30", "r31", "Z")]

# How many working registers to pack per row.
REGS_PER_ROW = 8

# SRAM regions to hexdump: (start_addr, length [, "label"]). Addresses are
# datasheet DATA-space; AVR64DD32 SRAM is 0x6000-0x7FFF (RAMEND 0x7FFF). The
# AvrSram module (avr_modules.py) shows addr + 16 hex bytes + ASCII per row and
# is auto-added to the layout when this list is non-empty. Dump the start of
# SRAM here; point at a .data/.bss label's address instead once you add one.
AVR_SRAM = [(0x6000, 0x80, "tasks"),(task_block, 0x80, "task_stacks"),(0x7ff0, 0x10, "stack")]
