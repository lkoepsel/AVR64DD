# Per-example gdb-dashboard config for asm_blink_pwm.
# Read by ~/.gdbinit.d/avr_modules.py when avr-gdb starts in this directory,
# overriding the module defaults. See docs/gdb-dashboard.md.
#
# This example drives TCA0 (Timer A) single-slope PWM on WO2 (PA2):
#   PER  sets the period (PWM frequency),  CMP2 sets the duty on WO2.

# Working register: setup loads PER / CMP2 / CTRLB / CTRLA through temp_16 (r16).
AVR_REG_SET = ["r16"]
AVR_REG_PAIRS = []
REGS_PER_ROW = 4

# TCA0 single-mode registers (addresses from avr/io.h / the AVR64DD32 datasheet).
#   name           addr     width
AVR_PERIPHERALS = [
    ("TCA0.CTRLA",  0x0A00,  1),   # ENABLE + CLKSEL  (clock source + run)
    ("TCA0.CTRLB",  0x0A01,  1),   # WGMODE + CMPnEN  (waveform mode + outputs)
    ("TCA0.CNT",    0x0A20,  2),   # live 16-bit counter
    ("TCA0.PER",    0x0A26,  2),   # period   -> PWM frequency
    ("TCA0.CMP2",   0x0A2C,  2),   # compare  -> duty cycle on WO2 (PA2)
]

# Per-bit decode for the 1-byte control registers (UPPER = set, lower = clear).
# (WGMODE / CLKSEL are multi-bit fields, so read those from the hex value.)
AVR_BITFIELDS = {
    "TCA0.CTRLA": [(0, "ENABLE")],
    "TCA0.CTRLB": [(6, "CMP2EN"), (5, "CMP1EN"), (4, "CMP0EN")],
}
