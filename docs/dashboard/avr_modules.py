# ============================================================================
#  avr_modules.py  --  gdb-dashboard custom module(s) for AVR (AVR64DD32)
# ----------------------------------------------------------------------------
#  Lives in  ~/.gdbinit.d/  -- gdb-dashboard auto-sources every file in that
#  directory at startup (a .py file here is exec'd as a Python module, after
#  the dashboard core but before the GDB-init pass). Requires gdb-dashboard
#  installed as ~/.gdbinit.
#
#  Provides one module:
#    AvrRegs  -- a CURATED subset of working registers + decoded SREG + PC,
#                instead of the built-in `registers` module's full 32-reg dump.
#                Reads live target state over GDB's remote protocol to Bloom;
#                pure terminal, works headless over SSH (no Insight / Qt).
#
#  The companion file  ~/.gdbinit.d/avr_layout.gdb  picks the dashboard layout
#  (source + assembly + avrregs) and hides the built-in modules.
#
#  Module name (for layout/toggle) is the lowercased class name: `avrregs`.
#    dashboard -layout source assembly avrregs
#    dashboard avrregs            (toggle visibility)
# ============================================================================

# ----------------------------------------------------------------------------
#  EDIT HERE: which working registers to show, in display order.
#  For asm_blink this is just the delay-loop temporaries r18/r19/r20
#  (temp_18 / temp_19 / temp_20 in Library/registers.S).
# ----------------------------------------------------------------------------
AVR_REG_SET = ["r18", "r19", "r20"]

# 16-bit pointer pairs to show as one combined value: (low, high, label).
# Empty for asm_blink (no X/Y/Z use). For later, e.g.:  [("r30", "r31", "Z")]
AVR_REG_PAIRS = []

# How many working registers to pack per row.
REGS_PER_ROW = 4


def _read_reg(name):
    """Read a core register by name from the selected frame. int or None.

    Falls back to the `$name` convenience variable: gdb always provides `pc`/`sp`
    via read_register(), but target-specific regs (notably SREG) must match the
    AVR tdesc name -- `$sreg` resolves it reliably."""
    try:
        return int(gdb.selected_frame().read_register(name))
    except Exception:
        pass
    try:
        return int(gdb.parse_and_eval('$' + name))
    except Exception:
        return None


class AvrRegs(Dashboard.Module):
    """Curated AVR working registers plus a decoded SREG and PC.

    Shows only the subset in AVR_REG_SET / AVR_REG_PAIRS (edit at the top of
    ~/.gdbinit.d/avr_modules.py) rather than all 32 GP registers, to keep the
    headless dashboard readable."""

    def label(self):
        return 'AVR Registers'

    def lines(self, term_width, term_height, style_changed):
        # No frame (not connected / target running) -> empty; divider greys out.
        try:
            gdb.selected_frame()
        except Exception:
            return []

        out = []

        # --- working register subset, packed REGS_PER_ROW per line ---
        cells = []
        for name in AVR_REG_SET:
            v = _read_reg(name)
            cells.append('{:>3}=??'.format(name) if v is None
                         else '{:>3}=0x{:02X}'.format(name, v & 0xFF))
        for i in range(0, len(cells), REGS_PER_ROW):
            out.append('  '.join(cells[i:i + REGS_PER_ROW]))

        # --- 16-bit pointer pairs (X/Y/Z), shown as combined values ---
        for low, high, lbl in AVR_REG_PAIRS:
            lo, hi = _read_reg(low), _read_reg(high)
            if lo is None or hi is None:
                out.append('{} ({}:{}) = ????'.format(lbl, high, low))
            else:
                combined = ((hi & 0xFF) << 8) | (lo & 0xFF)
                out.append('{} ({}:{}) = 0x{:04X}  ({})'.format(
                    lbl, high, low, combined, combined))

        # --- SREG decoded (UPPER = set, lower = clear) ---
        # Register name is "SREG" (uppercase); gdb is case-sensitive here.
        sreg = _read_reg('SREG')
        if sreg is not None:
            sreg &= 0xFF
            flags = [('I', 0x80), ('T', 0x40), ('H', 0x20), ('S', 0x10),
                     ('V', 0x08), ('N', 0x04), ('Z', 0x02), ('C', 0x01)]
            shown = ' '.join(n if (sreg & b) else n.lower() for n, b in flags)
            out.append('SREG = 0x{:02X}  [ {} ]'.format(sreg, shown))

        # --- program counter (byte address, matches the assembly window) ---
        # frame.pc() returns the byte code address (e.g. 0x12), not the AVR
        # hardware PC's word address (0x09) -- so it lines up with disassembly.
        try:
            pc = int(gdb.selected_frame().pc())
            out.append('PC   = 0x{:04X}'.format(pc & 0xFFFF))
        except Exception:
            pass

        return out
