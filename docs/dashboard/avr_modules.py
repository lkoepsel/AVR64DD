# ============================================================================
#  avr_modules.py  --  gdb-dashboard custom module(s) for AVR (AVR64DD32)
# ----------------------------------------------------------------------------
#  Lives in  ~/.gdbinit.d/  -- gdb-dashboard auto-sources every file in that
#  directory at startup (a .py file here is exec'd as a Python module, after
#  the dashboard core but before the GDB-init pass). Requires gdb-dashboard
#  installed as ~/.gdbinit.
#
#  Provides two modules:
#    AvrRegs        -- a CURATED subset of working registers + decoded SREG + PC,
#                      instead of the built-in `registers` module's 32-reg dump.
#    AvrPeripheral  -- selected memory-mapped peripheral registers (e.g. TCA0),
#                      the headless equivalent of Insight's peripheral pane.
#  Both read live target state over GDB's remote protocol to Bloom; pure
#  terminal, works headless over SSH (no Insight / Qt).
#
#  Module names (for layout/toggle) are the lowercased class names:
#    dashboard -layout source assembly avrregs avrperipheral
#    dashboard avrregs / dashboard avrperipheral   (toggle visibility)
#  avr_layout.gdb auto-adds avrperipheral to the layout when an example defines
#  AVR_PERIPHERALS (in its avr_dashboard.py).
# ============================================================================

# ----------------------------------------------------------------------------
#  DEFAULTS. These are usually overridden PER EXAMPLE by an `avr_dashboard.py`
#  in the directory you launch avr-gdb from (loaded just below). Put the
#  per-example file alongside each program's main.S and track it in the repo;
#  edit this block only to change the fallback used when no such file exists.
# ----------------------------------------------------------------------------
# Working registers to show, in display order.
AVR_REG_SET = ["r24", "r25"]

# 16-bit pointer pairs to show as one combined value: (low, high, label).
# e.g.  [("r30", "r31", "Z")]
AVR_REG_PAIRS = []

# How many working registers to pack per row.
REGS_PER_ROW = 4

# Memory-mapped peripheral registers to show: (name, address, width_bytes).
# Empty by default; an example's avr_dashboard.py fills this in (e.g. TCA0).
AVR_PERIPHERALS = []

# Optional per-bit decode for 1-byte peripheral registers, keyed by the name
# used in AVR_PERIPHERALS:  {name: [(bit_position, "FLAG"), ...]}.
AVR_BITFIELDS = {}

# SRAM regions to hexdump: (start_addr, length [, "label"]).  Addresses are
# datasheet DATA-space (AVR64DD32 SRAM is 0x6000-0x7FFF, RAMEND 0x7FFF); the
# _AVR_DATA_OFFSET is added automatically. Empty by default; an example's
# avr_dashboard.py fills this in, e.g.  [(0x6000, 32, "vars")].
AVR_SRAM = []


# ----------------------------------------------------------------------------
#  Per-example override: if the launch directory contains an `avr_dashboard.py`,
#  run it and adopt any of AVR_REG_SET / AVR_REG_PAIRS / REGS_PER_ROW /
#  AVR_PERIPHERALS / AVR_BITFIELDS / AVR_SRAM it defines.
#  This keeps the register selection tracked next to each example's source.
#  (The file is executed as Python, like a local ./.gdbinit -- only launch
#  avr-gdb in directories you trust.)
# ----------------------------------------------------------------------------
import os


def _load_example_overrides():
    path = os.path.join(os.getcwd(), 'avr_dashboard.py')
    if not os.path.exists(path):
        return
    ns = {}
    try:
        with open(path) as f:
            exec(f.read(), ns)
    except Exception as e:
        gdb.write('[avr_dashboard.py] {}\n'.format(e))
        return
    global AVR_REG_SET, AVR_REG_PAIRS, REGS_PER_ROW
    global AVR_PERIPHERALS, AVR_BITFIELDS, AVR_SRAM
    AVR_REG_SET = ns.get('AVR_REG_SET', AVR_REG_SET)
    AVR_REG_PAIRS = ns.get('AVR_REG_PAIRS', AVR_REG_PAIRS)
    REGS_PER_ROW = ns.get('REGS_PER_ROW', REGS_PER_ROW)
    AVR_PERIPHERALS = ns.get('AVR_PERIPHERALS', AVR_PERIPHERALS)
    AVR_BITFIELDS = ns.get('AVR_BITFIELDS', AVR_BITFIELDS)
    AVR_SRAM = ns.get('AVR_SRAM', AVR_SRAM)


_load_example_overrides()


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

    Shows only the subset in AVR_REG_SET / AVR_REG_PAIRS (set per example by an
    avr_dashboard.py in the launch directory, else the defaults at the top of
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

        # --- stack pointer (DATA-space address) ---
        # gdb provides 'sp' generically. After reset a freestanding handler must
        # load SP itself: if this reads 0x0000 (or some low reg/IO address) the
        # stack was never set up -- rcall/push/interrupt return all corrupt.
        # A healthy SP sits up near RAMEND and dips a little inside calls/ISRs.
        sp = _read_reg('sp')
        if sp is not None:
            out.append('SP   = 0x{:04X}'.format(sp & 0xFFFF))

        # --- program counter (byte address, matches the assembly window) ---
        # frame.pc() returns the byte code address (e.g. 0x12), not the AVR
        # hardware PC's word address (0x09) -- so it lines up with disassembly.
        try:
            pc = int(gdb.selected_frame().pc())
            out.append('PC   = 0x{:04X}'.format(pc & 0xFFFF))
        except Exception:
            pass

        return out


# avr-gdb maps the AVR DATA space (SRAM, I/O, peripheral registers) at this
# offset, separate from program/flash memory (Harvard architecture). Datasheet/
# io.h peripheral addresses are data-space, so add the offset -- without it you
# read FLASH at the same number (all 0xFF when that flash is unused).
_AVR_DATA_OFFSET = 0x800000


def _read_mem(addr, width):
    """Read `width` bytes from AVR DATA memory at datasheet address `addr`
    (e.g. 0x0A00), little-endian. Returns int or None."""
    try:
        buf = bytes(gdb.selected_inferior().read_memory(_AVR_DATA_OFFSET + addr, width))
        return int.from_bytes(buf, 'little')
    except Exception:
        return None


class AvrPeripheral(Dashboard.Module):
    """AVR memory-mapped peripheral registers (per example).

    Reads the registers listed in AVR_PERIPHERALS (set by the example's
    avr_dashboard.py) straight from target memory over Bloom -- the headless
    equivalent of Insight's peripheral pane. Optional per-bit decode via
    AVR_BITFIELDS."""

    def label(self):
        return 'AVR Peripherals'

    def lines(self, term_width, term_height, style_changed):
        if not AVR_PERIPHERALS:
            return []
        # No inferior (not connected) -> empty; divider greys out.
        try:
            gdb.selected_inferior()
        except Exception:
            return []

        namew = max(len(p[0]) for p in AVR_PERIPHERALS)
        out = []
        for name, addr, width in AVR_PERIPHERALS:
            v = _read_mem(addr, width)
            if v is None:
                valstr = '??'
            elif width == 1:
                valstr = '0x{:02X}'.format(v)
            elif width == 2:
                valstr = '0x{:04X} ({:>5})'.format(v, v)
            else:
                valstr = '0x{:0{w}X}'.format(v, w=width * 2)

            line = '{:<{nw}} @0x{:04X} = {}'.format(name, addr, valstr, nw=namew)

            bits = AVR_BITFIELDS.get(name)
            if v is not None and width == 1 and bits:
                decoded = ' '.join(fn if (v & (1 << bp)) else fn.lower()
                                   for bp, fn in bits)
                line += '  [ {} ]'.format(decoded)
            out.append(line)
        return out


def _read_bytes(addr, length):
    """Read `length` raw bytes from AVR DATA memory at datasheet address `addr`
    (e.g. 0x6000). Returns a bytes object, or None on failure."""
    try:
        return bytes(gdb.selected_inferior().read_memory(_AVR_DATA_OFFSET + addr, length))
    except Exception:
        return None


class AvrSram(Dashboard.Module):
    """AVR SRAM regions shown as a classic hexdump (per example).

    Dumps each region listed in AVR_SRAM (set by the example's avr_dashboard.py)
    straight from target memory over Bloom: data-space address, 16 hex bytes,
    and printable ASCII. AVR64DD32 SRAM is 0x6000-0x7FFF. Useful for watching
    .data/.bss variables or the stack without an Insight memory pane."""

    _PER_ROW = 16

    def label(self):
        return 'AVR SRAM'

    def lines(self, term_width, term_height, style_changed):
        if not AVR_SRAM:
            return []
        # No inferior (not connected) -> empty; divider greys out.
        try:
            gdb.selected_inferior()
        except Exception:
            return []

        out = []
        for entry in AVR_SRAM:
            start, length = entry[0], entry[1]
            lbl = entry[2] if len(entry) > 2 else ''
            header = '0x{:04X}..0x{:04X}'.format(start, start + length - 1)
            out.append('{}  {}'.format(lbl, header) if lbl else header)

            data = _read_bytes(start, length)
            if data is None:
                out.append('  ?? (unreadable)')
                continue
            for off in range(0, length, self._PER_ROW):
                chunk = data[off:off + self._PER_ROW]
                hexs = ' '.join('{:02X}'.format(b) for b in chunk)
                asci = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                out.append('  0x{:04X}  {:<{w}}  {}'.format(
                    start + off, hexs, asci, w=self._PER_ROW * 3 - 1))
        return out
