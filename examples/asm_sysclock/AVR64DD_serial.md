# AVR64DD32 Serial (USART0) Setup

This document is a step-by-step guide for driving the Curiosity Nano's USB CDC
serial port from AVR assembly, observing it from a host terminal, watching the
USART registers live in `gdb-dashboard`, and changing the baud rate.

The reference implementation is `Library/serial.S` (called from `main.S` in
this directory). Read this page alongside that file.

---

## 1. Hardware mapping (what "the serial port" is)

| Item                | Value                                        |
|---------------------|----------------------------------------------|
| Peripheral          | `USART0` on the AVR64DD32                    |
| TX pin              | `PD4`                                        |
| RX pin              | `PD5`                                        |
| PORTMUX position    | `ALT3` (PD4/PD5 are NOT the default pins)    |
| Host device         | `/dev/ttyACM0` (RPi) via the nEDBG CDC bridge|
| Default frame       | `8N1` (CTRLC default at reset — no write)    |

The single most common reason a from-scratch USART setup produces silence is
forgetting the PORTMUX step. USART0's reset-default pins are PA0/PA1; the
Curiosity Nano's CDC bridge is wired to PD4/PD5, which is the `ALT3` position.

---

## 2. Initialization sequence (`init_serial`)

`init_serial` performs exactly four steps, in this order:

1. **Route USART0 to PD4/PD5 via PORTMUX.**
   Write `(3 << PORTMUX_USART0_gp)` to `PORTMUX_USARTROUTEA`.
2. **Set PD4 as output (TX).**
   Write `(1 << 4)` to `PORTD_DIRSET`. PD5 stays input (RX).
3. **Write the 16-bit BAUD register, low byte first.**
   `lo8(BAUD_VAL)` to `USART0_BAUDL`, then `hi8(BAUD_VAL)` to `USART0_BAUDH`.
4. **Enable TX and RX in `USART0_CTRLB`.**
   Write `USART_TXEN_bm | USART_RXEN_bm`.

After `init_serial` returns, transmission is a poll-and-write loop:

```
1:  lds   r16, USART0_STATUS
    sbrs  r16, USART_DREIF_bp        ; wait for data register empty
    rjmp  1b
    sts   USART0_TXDATAL, r24        ; writing TXDATAL clears DREIF and starts TX
```

Reception is the mirror — poll `USART_RXCIF_bp`, then read `USART0_RXDATAL`.

---

## 3. Build, flash, and observe

From this directory:

```sh
make flash         # build main.hex and upload
```

On the host, open the CDC port. The example writes raw bytes (not ASCII), so
use a terminal that shows hex:

```sh
tio --map ODELBS /dev/ttyACM0      # tio with hex-dump mapping
# or
picocom -b 9600 /dev/ttyACM0       # baud must match BAUD_VAL in serial.S
```

You should see a frame per loop iteration: `0xBB <hi> <lo> 0xEE`, where
`<hi><lo>` is the elapsed-ticks delta (see `sysclock_timing.md`).

---

## 4. Adding USART0 to `avr_dashboard.py`

`avr_dashboard.py` is the per-example override read by `~/.gdbinit.d/avr_modules.py`
when `avr-gdb` starts in this directory. To watch USART0 alongside TCA0,
append its registers to `AVR_PERIPHERALS` and decode the status bits in
`AVR_BITFIELDS`.

USART0 base address is `0x0800` on the AVR64DD32. The relevant offsets:

| Register           | Address | Width |
|--------------------|---------|-------|
| `USART0.CTRLA`     | 0x0805  | 1     |
| `USART0.CTRLB`     | 0x0806  | 1     |
| `USART0.CTRLC`     | 0x0807  | 1     |
| `USART0.BAUD`      | 0x0808  | 2     |
| `USART0.STATUS`    | 0x0804  | 1     |
| `USART0.TXDATAL`   | 0x0802  | 1     |
| `USART0.RXDATAL`   | 0x0800  | 1     |

Edit `avr_dashboard.py` and extend the existing `AVR_PERIPHERALS` list:

```python
AVR_PERIPHERALS = [
    ("TCA0.CTRLA",    0x0A00, 1),
    ("TCA0.CTRLB",    0x0A01, 1),
    ("TCA0.CNT",      0x0A20, 2),
    ("TCA0.PER",      0x0A26, 2),
    ("TCA0.CMP2",     0x0A2C, 2),
    # --- USART0 ---
    ("USART0.STATUS", 0x0804, 1),
    ("USART0.CTRLB",  0x0806, 1),
    ("USART0.BAUD",   0x0808, 2),
]

AVR_BITFIELDS = {
    "TCA0.CTRLA":   [(0, "ENABLE")],
    "TCA0.CTRLB":   [(6, "CMP2EN"), (5, "CMP1EN"), (4, "CMP0EN")],
    # --- USART0.STATUS bits worth watching during transmit/receive ---
    "USART0.STATUS": [(7, "RXCIF"), (6, "TXCIF"), (5, "DREIF"), (2, "BUFOVF")],
    "USART0.CTRLB":  [(6, "RXEN"),  (7, "TXEN")],
}
```

Confirm `PORTMUX_USART0_gp` and the addresses against the in-tree header:

```sh
grep -E 'PORTMUX_USART0|USARTROUTEA|USART0_BAUDL|USART0_STATUS' \
     /usr/lib/avr/include/avr/ioavr64dd32.h
```

(See `documentation/ioavr64dd32.md` for the markdown copy.)

To watch a transmit live:

```sh
avr-gdb main.elf
(gdb) target remote :1442          # Bloom GDB server (see bloom.yaml)
(gdb) break char_write
(gdb) continue
```

On each break, the dashboard's peripheral pane shows `USART0.STATUS` with
`DREIF` set going in and `TXCIF` flipping after `sts USART0_TXDATAL, r24`.

---

## 5. Changing the baud rate

Baud is set by one `#define` near the top of `Library/serial.S`:

```c
#define BAUD_VAL  1667        // 4 MHz, 9600 baud
```

The formula (normal async, 16x oversampling):

```
BAUD_VAL = (64 * F_CPU) / (16 * baud_rate)
         = (4  * F_CPU) / baud_rate
```

Worked values for the two clocks this repo supports:

| F_CPU  | Baud   | BAUD_VAL | Hex     | % error  | Notes                              |
|--------|--------|----------|---------|----------|------------------------------------|
| 4 MHz  | 9600   | 1667     | 0x0683  | <0.1%    | Reset-default clock; recommended   |
| 4 MHz  | 38400  | 417      | 0x01A1  | ~0.1%    | Safe at default clock              |
| 4 MHz  | 115200 | 139      | 0x008B  | ~1.4%    | Marginal — host may see framing err|
| 24 MHz | 115200 | 833      | 0x0341  | <0.1%    | Requires CLKCTRL bump first        |

To change the baud rate:

1. Pick a target rate that matches your terminal program.
2. Compute `BAUD_VAL` with the formula above (or use the table).
3. Edit the `#define BAUD_VAL` line in `Library/serial.S`.
4. `make clean && make flash` from this example directory.
5. Restart your terminal program at the new baud rate
   (e.g. `picocom -b 38400 /dev/ttyACM0`).

To run at 115200, you must first switch the main clock to 24 MHz via CLKCTRL
before `init_serial` runs — at the 4 MHz reset-default clock, 115200 has
enough rounding error to be unreliable for sustained traffic.

---

## 6. Verification checklist

| Symptom                                | Likely cause                                                  |
|----------------------------------------|---------------------------------------------------------------|
| Terminal shows nothing                 | PORTMUX not set, or wrong CDC device                          |
| Garbled output                         | Host baud ≠ `BAUD_VAL`, or wrong `F_CPU`                       |
| First few bytes garbled, then OK       | `init_serial` called before clock settled                     |
| `DREIF` never sets in dashboard        | `USART0_CTRLB` write missing (TX not enabled)                 |
| `TXEN`/`RXEN` clear in dashboard       | Address typo in `AVR_PERIPHERALS`                             |

All symbol names used above are visible to `avr-as` through the
`_gp`/`_bm`/`_bp` defines in `ioavr64dd32.h`. The `*_gc` enum group codes are
C-only — see `serial.S` for the `(3 << PORTMUX_USART0_gp)` pattern used in
place of `PORTMUX_USART0_ALT3_gc`.
