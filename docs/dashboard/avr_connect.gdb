# ============================================================================
#  avr_connect.gdb  --  one-shot "attach + flash" command (Bloom OR PyAvrOCD)
# ----------------------------------------------------------------------------
#  Sourced by gdb-dashboard's GDB-init pass. Defines a `connect` command that
#  reproduces the original classroom start: attach to the GDB server, set a
#  breakpoint at the reset vector, and flash the program. Run it once after
#  starting avr-gdb; the core halts at 0x0 and the dashboard repaints on that
#  stop. Ends with a `dashboard` redisplay, which clears the startup banner and
#  the attach/flash chatter, leaving a clean dashboard halted at the vector.
#
#  Two servers are supported, tried in this order:
#
#      127.0.0.1:2000   PyAvrOCD   (macOS; pyavrocd's default port)
#      127.0.0.1:1442   Bloom      (Linux; the port set in bloom.yaml)
#
#  Bloom's behaviour is unchanged: on a Linux box running bloom, :2000 simply
#  refuses the connection and :1442 attaches exactly as before. Pass an explicit
#  port to force one, e.g.  `connect 1442`.
# ============================================================================
python
AVR_SERVERS = [(2000, 'PyAvrOCD'), (1442, 'Bloom')]


class _AvrConnect(gdb.Command):
    """Attach to an AVR GDB server, break at the reset vector, flash, redraw.

Tries PyAvrOCD (127.0.0.1:2000) first, then Bloom (127.0.0.1:1442).
Give a port to force one, e.g. `connect 1442`."""

    def __init__(self):
        super(_AvrConnect, self).__init__('connect', gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        arg = (arg or '').strip()
        if arg:
            try:
                servers = [(int(arg), 'port ' + arg)]
            except ValueError:
                raise gdb.GdbError('connect: expected a port number, got %r' % arg)
        else:
            servers = AVR_SERVERS
        for port, name in servers:
            try:
                gdb.execute('target extended-remote 127.0.0.1:%d' % port,
                            to_string=True)
            except gdb.error:
                continue
            gdb.write('[avr] attached to %s on 127.0.0.1:%d\n' % (name, port))
            gdb.execute('break *0')
            gdb.execute('load')
            gdb.execute('dashboard')
            return
        tried = ', '.join('%s (:%d)' % (n, p) for p, n in servers)
        gdb.write('[avr] no GDB server found -- tried %s.\n'
                  '[avr] start one, then type `connect`.\n' % tried)


_AvrConnect()
end
