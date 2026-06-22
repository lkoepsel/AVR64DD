# ============================================================================
#  avr_commands.gdb  --  classroom convenience commands (restored)
# ----------------------------------------------------------------------------
#  Sourced by gdb-dashboard's GDB-init pass.
# ============================================================================

# cll -- rebuild, reload onto the target, and list source.
define cll
make
load
l
end
document cll
Rebuild (make), reload the new program onto the target, and list source.
The dashboard also repaints automatically on the reload's stop.
end

# mrc -- reset to the reset vector (0x00) and run.
define mrc
mon reset
continue
end
document mrc
Reset the target to the reset vector (0x00) and continue (run).
end
