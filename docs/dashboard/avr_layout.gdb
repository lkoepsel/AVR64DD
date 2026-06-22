# ============================================================================
#  avr_layout.gdb  --  gdb-dashboard layout for AVR assembly debugging
# ----------------------------------------------------------------------------
#  Sourced by gdb-dashboard in its GDB-init pass, i.e. AFTER avr_modules.py
#  has been loaded, so the custom `avrregs` module already exists here.
#
#  `dashboard -layout` first DISABLES every module, then enables only the ones
#  listed, in order. Listing just these three hides the built-in `registers`
#  module (the full 32-register dump) and everything else.
#
#    source         -- the main.S source window (built from -g/-gdwarf-2)
#    assembly       -- live disassembly with the PC marker
#    avrregs        -- curated working regs + decoded SREG + PC (avr_modules.py)
#    avrperipheral  -- added only when the example's avr_dashboard.py defines
#                      AVR_PERIPHERALS (e.g. TCA0 for asm_blink_pwm)
# ============================================================================
python
_layout = ['source', 'assembly', 'avrregs']
if AVR_PERIPHERALS:
    _layout.append('avrperipheral')
gdb.execute('dashboard -layout ' + ' '.join(_layout))
end

# Shorter source panel (default is 10 lines). Tweak to taste.
dashboard source -style height 12

# Hide the Assembly "function+offset" column (the '?' you saw when labels had
# no function symbol). Centering still works -- it uses the function boundaries
# from the .type/.size symbols, not this column.
dashboard assembly -style function False
