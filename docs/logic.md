# Logic in Assembly Language

## Shift Left in Assembly Language

`(0x03 << 0)` is a left-shift expression that produces the value to write into the WGMODE field.

**The two operands:**

- `0x03` — the value, in hexadecimal. In binary that's `0b011` (decimal 3). This is the code that means "single-slope PWM mode."
- `0` — the number of bit positions to shift left. This comes from `_gp`, the group position (where the field's LSB sits in the register).

**The shift operation:**

`<<` moves every bit to the left by the given count, filling vacated low bits with zeros. Shifting by `0` moves nothing, so the result is just `0b011` unchanged.

```
0x03         = 0000 0011
0x03 << 0    = 0000 0011   (no movement)
```

So `(0x03 << 0)` evaluates to `0x03` = `0b00000011`. Bits 1 and 0 are set, which is exactly where the 3-bit WGMODE field lives (bits 2:0).

**Why the `<< 0` is there at all** — it's a template the header generator applies to *every* field, so the shift amount equals that field's `_gp`. WGMODE happens to start at bit 0, so the shift is 0 and looks like a no-op. To see why it matters, consider a field that doesn't start at bit 0.

Take CMP0EN in TCA's CTRLB, which sits at bit 4. If its enum value were 1, the header would write `(0x01 << 4)`:

```
0x01         = 0000 0001
0x01 << 4    = 0001 0000   (moved 4 places left)
```

That gives `0x10` — the bit landing in position 4, where the hardware expects it.

So the pattern `(value << _gp)` always places `value` into the correct field position. For WGMODE the `_gp` is 0, making `(0x03 << 0)` the same as plain `0x03` — the shift is there for consistency, not because it changes anything in this particular case.