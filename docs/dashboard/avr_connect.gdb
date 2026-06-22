# ============================================================================
#  avr_connect.gdb  --  one-shot "attach + flash" command for Bloom
# ----------------------------------------------------------------------------
#  Sourced by gdb-dashboard's GDB-init pass. Defines a `connect` command that
#  reproduces the original classroom start: attach to Bloom, set a breakpoint
#  at the reset vector, and flash the program. Run it once after starting
#  avr-gdb; the core halts at 0x0 and the dashboard repaints on that stop.
#  Ends with a `dashboard` redisplay, which clears the startup banner and the
#  attach/flash chatter and leaves a clean dashboard (halted at the vector).
# ============================================================================
define connect
  target extended-remote 127.0.0.1:1442
  break *0
  load
  # Clear the banner + attach/flash messages, then draw a clean dashboard.
  dashboard
end
document connect
Attach to Bloom's GDB server (127.0.0.1:1442), set a breakpoint at the reset
vector, and flash the program. Run once after avr-gdb starts; the core halts
at 0x0 and the dashboard repaints. Continue with 'c', single-step with 'si'.
end
