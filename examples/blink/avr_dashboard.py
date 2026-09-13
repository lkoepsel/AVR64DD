# gdb-dashboard register selection for blink:
# Read by ~/.gdbinit.d/avr_modules.py when avr-gdb starts in this directory,
# overriding the module defaults. See docs/gdb-dashboard.md.

# NOTE: PF5 - The user LED on the Curiosity Nano is active low. If you wish
#		it to be active high, write a 0x80 to PORTF.PIN5CTRL, the INVEN bit

# Working registers to show, in display order. blink's delay loop is the
# delay_16 macro, which writes only r18/r19 -- named delay_18 / delay_19 in
# Library/registers.S. (r20 is temp_20 there; delay_16 never touches it.)
AVR_REG_SET = ["r18", "r19"]

# 16-bit pointer pairs to show as one combined value: (low, high, label).
# Empty for blink (no X/Y/Z use). For later, e.g.:  [("r30", "r31", "Z")]
AVR_REG_PAIRS = []

# How many working registers to pack per row.
REGS_PER_ROW = 4

AVR_PERIPHERALS = [
       ("VPORTF.DIR",  0x0014,  1),
       ("VPORTF.OUT",  0x0015,  1),
       ("VPORTF.IN",   0x0016,  1),
   ]
