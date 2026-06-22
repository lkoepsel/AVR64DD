# ============================================================================
#  avr_autostart.py  --  global auto-connect (replaces per-example ./.gdbinit)
# ----------------------------------------------------------------------------
#  If a `main.elf` exists in the directory you launched gdb from, automatically
#  `file` it and `connect` (attach to Bloom + break *0 + load), leaving you
#  halted at the reset vector with the dashboard drawn. Plain `gdb` in any other
#  directory is unaffected -- the guard is the presence of main.elf.
#
#  Deferred to the first prompt (one-shot) so it runs AFTER gdb-dashboard has
#  finished initializing; otherwise the dashboard would be inhibited and would
#  not render. `connect` is defined in avr_connect.gdb (loaded during init).
# ============================================================================
import os


def _avr_autostart():
    # one-shot: detach so it only fires on the first prompt
    gdb.events.before_prompt.disconnect(_avr_autostart)
    if not os.path.exists('main.elf'):
        return
    try:
        gdb.execute('file main.elf')
        gdb.execute('connect')
    except gdb.error as e:
        gdb.write('[avr autostart] {}\n'.format(e))


gdb.events.before_prompt.connect(_avr_autostart)
