# ============================================================================
#  avr_autostart.py  --  global auto-connect (replaces per-example ./.gdbinit)
# ----------------------------------------------------------------------------
#  When gdb reaches its first prompt, if a `main.elf` exists in the directory
#  you launched gdb from, automatically `file` it and `connect` (attach to
#  Bloom + break *0 + load), leaving you halted at the reset vector with the
#  dashboard drawn. Plain `gdb` elsewhere is unaffected -- the guard is the
#  presence of main.elf.
#
#  It re-arms while main.elf is absent (so building then is enough; no relaunch)
#  and reports clearly if it skips or if connect fails, so it never looks like
#  "nothing happened." `connect` is defined in avr_connect.gdb (loaded at init).
# ============================================================================
import os

_avr_done = []     # set once we've actually connected (or tried with a main.elf)


def _avr_autostart():
    if _avr_done:
        return
    if not os.path.exists('main.elf'):
        # No program here yet -- stay armed; building it will trigger us on the
        # next prompt. (Silent: plain gdb in a non-AVR dir shouldn't be noisy.)
        return
    _avr_done.append(True)
    try:
        gdb.execute('file main.elf')
        gdb.execute('connect')
    except gdb.error as e:
        gdb.write("[avr] auto-connect failed: {}  --  type 'connect' to retry.\n"
                  .format(e))


gdb.events.before_prompt.connect(_avr_autostart)
