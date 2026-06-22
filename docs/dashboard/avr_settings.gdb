# ============================================================================
#  avr_settings.gdb  --  global gdb preferences for the AVR/Bloom workflow
# ----------------------------------------------------------------------------
#  Sourced by gdb-dashboard's GDB-init pass (applies to every gdb session).
# ============================================================================

# Don't prompt on `q`, symbol reloads, etc.
set confirm off

# Match the old classroom .gdbinit.
set listsize 0

# Allow per-project ./.gdbinit files under the repo to auto-load (used for the
# per-example auto-connect). gdb otherwise refuses CWD init files for safety.
# !! CHANGE this to the absolute path of YOUR clone of this repo !!
add-auto-load-safe-path /home/lkoepsel/Documents/AVR64DD
