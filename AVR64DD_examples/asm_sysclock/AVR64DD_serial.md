The Curiosity Nano's serial port is the **USART** connected to the onboard nEDBG debugger's CDC virtual COM port — so "accessing the serial port" means driving one of the AVR64DD32's USART peripherals in assembly. Let me lay out which USART, the wiring, and the code pattern. First let me verify the specific pin mapping for the AVR64DD32 Curiosity Nano's CDC connection, since that's board-specific and I don't want to state it from memory.The board wiring is confirmed. Here's what "the serial port" means physically and how to drive it in assembly.

The Curiosity Nano routes the USB CDC virtual COM port to **USART0** on the AVR64DD32: PD4 is USART0 TX and PD5 is USART0 RX. The nEDBG debugger presents that as a `/dev/ttyACM*` device on your RPi when the board is plugged in. So a host terminal (or `screen`/`minicom`/`picocom`/`tio` on the RPi) talking to that ACM device is talking to USART0 on your target.

One important board-specific wrinkle from the schematic: USART0's CDC connection is on **PD4/PD5**, but those aren't USART0's default pin positions on the AVR64DD32 — Microchip's own out-of-the-box example notes that USART0 is routed to the CDC pins by using Port Multiplexing. That means in addition to configuring the USART, you must set the **PORTMUX** to move USART0 onto the alternate (PD4/PD5) location. Miss that step and your bytes go to the wrong pins and nothing reaches the terminal — it's the single most common reason a from-scratch USART setup on this board produces silence.

The setup sequence in assembly, conceptually:

The four things `init` must do, in order: set PORTMUX so USART0 uses the PD4/PD5 alternate pins; make PD4 an output (TX) and leave PD5 as input (RX); write the baud register `USART0.BAUD` with the value for your target baud at your clock; then enable TX (and RX) in `USART0.CTRLB`. After that, transmit is a poll-and-write loop on the data register.

The baud formula for these AVR-Dx USARTs in normal (16×) async mode is:

```
BAUD = (64 * F_CPU) / (16 * baud_rate) = (4 * F_CPU) / baud_rate
```

The result is a 16-bit value written low-byte then high-byte to `USART0.BAUDL`/`USART0.BAUDH`. Two worked examples for the rates the board uses:

At the **4 MHz** post-reset clock, 115200 baud: `(4 × 4000000) / 115200 ≈ 139` (0x008B). Note Microchip's examples run the board at 24 MHz for 115200 baud — at 24 MHz the value is `(4 × 24000000) / 115200 ≈ 833` (0x0341), which has much lower rounding error. For classroom reliability at 115200 you'll likely want to bump the clock to 24 MHz via CLKCTRL (the software clock change we worked through earlier); at 4 MHz, 115200 has enough error that 9600 baud is the safer choice if you stay at default clock.

Here's a transmit-only module written in your house style. Let me build it:That's a transmit/receive USART0 module in your house style — banner header, "Registers and Values" block, `lpm Z+` string-send mirroring your tiny13 LPM pattern, blocking poll loops kept short.

The conceptual answer to "how do I access the serial port in assembly," in four steps:

The serial port on this board is **USART0 routed to PD4 (TX) / PD5 (RX)**, surfaced on your RPi as `/dev/ttyACM0`. To drive it you (1) set **PORTMUX** to move USART0 onto those alternate pins — the step that's easy to miss and produces silence if skipped — (2) make PD4 an output via `PORTD.DIRSET`, (3) write the 16-bit **BAUD** value, and (4) enable TX/RX in `USART0.CTRLB`. Then transmitting is: poll `DREIF` in `USART0.STATUS`, write the byte to `USART0.TXDATAL`. Receiving is the mirror: poll `RXCIF`, read `USART0.RXDATAL`.

The clock/baud coupling is the thing to get right for your class. The module defaults to **4 MHz / 9600 baud** (BAUD = 1667), which is reliable at the post-reset clock. If you want 115200 to match Microchip's examples, you need the 24 MHz clock (the CLKCTRL software bump we worked through earlier) — at 4 MHz, 115200 carries enough rounding error to be flaky. The header comment block has all three baud values worked out so you can switch with one `#define`.

Same verification caveats as the other modules, since I can't assemble here:

The PORTMUX symbol — `PORTMUX_USART0_ALT1_gc` and `PORTMUX_USARTROUTEA`. Confirm with `grep -E 'PORTMUX_USART0|USARTROUTEA' ioavr64dd32.h`. The ALT position that lands on PD4/PD5 is the one to use; if the header calls it something other than `ALT1`, match it. This is the highest-risk line in the file.

The flat register/bit symbols — `USART0_STATUS`, `USART0_TXDATAL`, `USART_DREIF_bp`, `USART_TXEN_bm`, `PORTD_DIRSET`. If avr-as rejects any flat `USART0_*` name (struct-only header versions), the fix is numeric addresses, same as we discussed for the TCA0 module.

There's a clean teaching arc here connecting everything: this serial module plus the `sysclock_dd32` timer module gives you a program that ticks every millisecond and prints over USART — and on the headless RPi, students watch it happen three ways at once: the byte going out on `/dev/ttyACM0` in their terminal, the `TCA0.CNT` register cycling in the gdb-dashboard peripheral pane, and `USART0.STATUS` flags flipping as each byte transmits. Want me to write a small `main.S` that ties the timer and serial together — say, printing a counter once per second — as the capstone example, and add USART0's registers to your dashboard's `AVR_PERIPHERALS` list so they're visible during the demo?

