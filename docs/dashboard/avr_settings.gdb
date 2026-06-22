# ============================================================================
#  avr_settings.gdb  --  global gdb preferences for the AVR/Bloom workflow
# ----------------------------------------------------------------------------
#  Sourced by gdb-dashboard's GDB-init pass (applies to every gdb session).
# ============================================================================

# Don't prompt on `q`, symbol reloads, etc.
set confirm off

set listsize 0

# Keep command history in ONE global file (~/.gdb_history) instead of letting
# gdb drop a .gdb_history in every directory you debug from.
set history save on
set history size 10000
set history filename ~/.gdb_history
