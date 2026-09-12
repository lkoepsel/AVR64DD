# Per-example gdb-dashboard register selection for blink.
# Read by ~/.gdbinit.d/avr_modules.py when avr-gdb starts in this directory,
# overriding the module defaults. See docs/gdb-dashboard.md.

# Working registers to show, in display order. blink's delay loop is the
# delay_16 macro, which writes only r18/r19 -- named delay_18 / delay_19 in
# Library/registers.S. (r20 is temp_20 there; delay_16 never touches it.)
AVR_REG_SET = ["r18", "r19"]

# 16-bit pointer pairs to show as one combined value: (low, high, label).
# Empty for blink (no X/Y/Z use). For later, e.g.:  [("r30", "r31", "Z")]
AVR_REG_PAIRS = []

# How many working registers to pack per row.
REGS_PER_ROW = 4
