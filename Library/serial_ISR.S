; ====================================================================
;  serial_ISR - interrupt-driven USART0 with RX and TX ring buffers
;       init_serial     - configure USART0 on the Curiosity Nano CDC pins
;       char_write      - queue one byte (in r24) for transmission
;       word_write      - queue two bytes (in r25/r24)
;       flash_write     - queue a zero-terminated string (Z -> flash)
;       char_read       - return one byte (in r24), waits if none buffered
;       char_available  - count of bytes waiting in the RX buffer (r24)
;       flush_serial    - wait until everything queued is on the wire
;
;       __vector_21     - USART0 RXC ISR, stores arriving bytes in rx_buf
;       __vector_22     - USART0 DRE ISR, feeds tx_buf to the transmitter
; Target : AVR64DD32 (Curiosity Nano)
; Clock  : see F_CPU note below -- baud value depends on it
; Toolchain: avr-as / avr-ld  (GNU Binutils for AVR)
;
;  This is the interrupt version of serial.S. Same public names, same
;  calling convention, so an example switches versions by changing which
;  file it includes -- nothing else in main.S has to change EXCEPT:
;
;    1. the .vectors table must be long enough to reach vector 22, with
;       slot 21 -> __vector_21 and slot 22 -> __vector_22, and
;    2. main must execute sei once after init_serial.
;
;  Both are easy to forget and both fail silently (no output, or an echo
;  that never returns) -- see examples/ring/main.S for a working table.
;
;  Why bother, when polling works?  In serial.S, char_write spins until
;  the transmitter is free and char_read spins until a byte arrives, so
;  the CPU can do nothing else while characters trickle by at 9600 baud
;  (~1 ms per character). Here the ISRs move bytes in the background and
;  the mainline only touches the ring buffers, so a byte that arrives
;  while main is busy elsewhere is buffered instead of lost.
;
;  The Curiosity Nano wires the USB CDC virtual COM port to USART0:
;       PD4 = USART0 TX,  PD5 = USART0 RX
;  BUT these are USART0's ALTERNATE pins, so PORTMUX must route USART0
;  to them. Skipping the PORTMUX step is the #1 cause of "no output".
; ====================================================================

; Dependencies -- included here so this module assembles standalone
#include <avr/io.h>
#include "registers.S"

; --------------------------------------------------------------------
;  CLOCK + BAUD
;  BAUD register = (64 * F_CPU) / (16 * baud) = (4 * F_CPU) / baud
;
;  Pick ONE matching your actual main clock:
;    4 MHz  (post-reset default):   9600 -> 1667 (0x0683)   [recommended]
;    4 MHz                       : 115200 ->  139 (0x008B)   [~1.4% err, risky]
;   24 MHz  (after CLKCTRL bump) : 115200 ->  833 (0x0341)   [low error]
;
;  Defaults below: 4 MHz / 9600 baud. Change BAUD_VAL to match your setup.
; --------------------------------------------------------------------
#define BAUD_VAL  1667        // 4 MHz, 9600 baud  (cpp keeps ';' in a #define, so use //)

; --------------------------------------------------------------------
;  RING BUFFER SIZES
;
;  Each size MUST be a power of two and its mask MUST be size-1: the
;  wrap-around is done with andi (one instruction), not a compare, so a
;  non-power-of-two size silently corrupts the indices.
;
;  A ring holds size-1 bytes, not size: head == tail means "empty", so
;  the head is never allowed to catch up to the tail. 32 -> 31 bytes,
;  about 32 ms of slack at 9600 baud, plenty for a line of typing.
; --------------------------------------------------------------------
#define RX_SIZE   32
#define RX_MASK   (RX_SIZE - 1)
#define TX_SIZE   32
#define TX_MASK   (TX_SIZE - 1)

; --------------------------------------------------------------------
;  CTRLA values, written whole rather than read-modify-write.
;
;  CTRLA holds every USART0 interrupt enable, so flipping DREIE with an
;  lds/ori/sts sequence would be a read-modify-write that an RXC
;  interrupt can land in the middle of -- and the stale value written
;  back would switch the receiver off. We know exactly which interrupts
;  this module uses, so we just store the whole byte.
; --------------------------------------------------------------------
#define CTRLA_RX_ONLY   USART_RXCIE_bm                    // idle: RX interrupt only
#define CTRLA_RX_TX     (USART_RXCIE_bm | USART_DREIE_bm) // draining tx_buf

; ====================================================================
;  TEXT SECTION
; ====================================================================
.section .text

; ---------- Registers and Values ----------------
; r24                   ; char register - byte to send / received byte
; r16, r17              ; temp registers - scratch
; X (r27:r26)           ; ring buffer pointer (saved/restored by every
;                       ;   routine here, so oneline_mt's task pointer
;                       ;   survives a serial call)
; Z (r31:r30)           ; flash pointer for flash_write - never touched
;                       ;   by char_write, so the string loop is safe
; r3 (ISR_3)            ; SREG save inside both ISRs. Deliberately NOT
;                       ;   ISR_2, which sysclock.S uses -- the two
;                       ;   modules are often linked together.
; r1                    ; assumed 0 (repo convention, set by reset_handler)
;                       ;   for the 16-bit pointer adds below

; --------------------------------------------------------------------
;  __vector_21 - USART0 RXC: a byte arrived
;
;  Fires once per received character. Reading RXDATAL is what clears
;  RXCIF, so EVERY path through this ISR must read it -- including the
;  buffer-full path, or the interrupt re-fires forever and the CPU
;  never returns to main.
;
;  Overflow policy: when the ring is full the new byte is dropped. The
;  alternative (overwrite the oldest) loses the start of the line
;  instead of the end, which is harder to notice.
; --------------------------------------------------------------------
.global USART0_RXC_handler
USART0_RXC_handler:
    in      ISR_3, CPU_SREG         ; save status flags
    push    temp_16
    push    temp_17
    push    tasks_26                ; X lo
    push    tasks_27                ; X hi

    ; --- next head = (head + 1) & mask; if it equals tail we are full ---
    lds     temp_16, rx_head
    mov     temp_17, temp_16        ; temp_17 = current head = store index
    inc     temp_16
    andi    temp_16, RX_MASK        ; temp_16 = next head
    lds     tasks_26, rx_tail
    cp      temp_16, tasks_26
    breq    1f                      ; full -> discard the byte

    ; --- room available: store rx_buf[head] = RXDATAL ---
    ldi     tasks_26, lo8(rx_buf)
    ldi     tasks_27, hi8(rx_buf)
    add     tasks_26, temp_17       ; X = &rx_buf[head]
    adc     tasks_27, r1            ; r1 == 0 (zero register)
    lds     temp_17, USART0_RXDATAL ; read the byte (clears RXCIF)
    st      X, temp_17
    sts     rx_head, temp_16        ; publish the new head last
    rjmp    2f

1:  ; --- buffer full: still must read RXDATAL to clear RXCIF ---
    lds     temp_17, USART0_RXDATAL

2:  pop     tasks_27
    pop     tasks_26
    pop     temp_17
    pop     temp_16
    out     CPU_SREG, ISR_3         ; restore status flags
    reti

; --------------------------------------------------------------------
;  __vector_22 - USART0 DRE: the transmit data register is free
;
;  DREIF is a level, not an edge: it stays set for as long as the data
;  register is empty, so this ISR would re-fire forever once tx_buf runs
;  dry. Writing TXDATAL clears it for one character; when there is
;  nothing left to write, the only way out is to switch DREIE off. That
;  is why char_write has to switch it back on after queueing a byte.
; --------------------------------------------------------------------
.global USART0_DRE_handler
USART0_DRE_handler:
    in      ISR_3, CPU_SREG         ; save status flags
    push    temp_16
    push    temp_17
    push    tasks_26                ; X lo
    push    tasks_27                ; X hi

    lds     temp_16, tx_tail
    lds     temp_17, tx_head
    cp      temp_16, temp_17
    breq    1f                      ; empty -> stop asking for data

    ; --- send tx_buf[tail] ---
    ldi     tasks_26, lo8(tx_buf)
    ldi     tasks_27, hi8(tx_buf)
    add     tasks_26, temp_16       ; X = &tx_buf[tail]
    adc     tasks_27, r1            ; r1 == 0 (zero register)
    ld      temp_17, X
    ; clear TXCIF before each write so it means "the last queued byte
    ; has finished shifting out" -- flush_serial waits on exactly that
    ldi     tasks_26, USART_TXCIF_bm
    sts     USART0_STATUS, tasks_26
    sts     USART0_TXDATAL, temp_17 ; the write clears DREIF
    inc     temp_16
    andi    temp_16, TX_MASK
    sts     tx_tail, temp_16        ; consume the byte
    rjmp    2f

1:  ; --- nothing queued: disable DREIE or this ISR spins forever ---
    ldi     temp_16, CTRLA_RX_ONLY
    sts     USART0_CTRLA, temp_16

2:  pop     tasks_27
    pop     tasks_26
    pop     temp_17
    pop     temp_16
    out     CPU_SREG, ISR_3         ; restore status flags
    reti

; --------------------------------------------------------------------
;  init_serial - USART0 on PD4/PD5 via PORTMUX, 8N1, TX+RX, RX interrupt
;
;  The caller must execute sei afterwards. Nothing here does it, so that
;  main can finish setting up its other peripherals before any ISR runs
;  (same convention as init_sysclock_1k in sysclock.S).
; --------------------------------------------------------------------
.global init_serial
init_serial:
    ; --- 0. Empty both rings ---
    ;     .bss is NOT zeroed in a freestanding (assembly-only) build --
    ;     there is no C runtime to do it -- so the indices start as
    ;     whatever was in SRAM at power-up. Clearing them here is what
    ;     makes this module work in both build flavours.
    sts     rx_head, r1             ; r1 == 0 (zero register)
    sts     rx_tail, r1
    sts     tx_head, r1
    sts     tx_tail, r1

    ; --- 1. Route USART0 to its ALTERNATE pins (PD4/PD5) via PORTMUX ---
    ;     PORTMUX.USARTROUTEA, USART0 field = ALT3 (TxD=PD4, RxD=PD5).
    ;     The *_gc group codes live in a C enum in modern avr-libc, so the
    ;     assembler can't see them -- build the value from the *_gp #define
    ;     instead.  (ALT3 value = 3; ALT1 = PA4/PA5, the wrong pins.)
    ldi     temp_16, (3 << PORTMUX_USART0_gp)    ; ALT3 -> PD4 TX / PD5 RX (Nano CDC)
    sts     PORTMUX_USARTROUTEA, temp_16

    ; --- 2. PD4 (TX) as output; PD5 (RX) stays input (default) ---
    ldi     temp_16, (1 << 4)          ; PIN4 = PD4 = TX
    sts     PORTD_DIRSET, temp_16

    ; --- 3. Baud rate: 16-bit write, low then high ---
    ldi     temp_16, lo8(BAUD_VAL)
    sts     USART0_BAUDL, temp_16
    ldi     temp_16, hi8(BAUD_VAL)
    sts     USART0_BAUDH, temp_16

    ; --- 4. Enable transmitter and receiver ---
    ;     USART0.CTRLB: TXEN and RXEN bits.
    ldi     temp_16, USART_TXEN_bm | USART_RXEN_bm
    sts     USART0_CTRLB, temp_16

    ; --- 5. Enable the RX interrupt; DREIE stays off until there is
    ;        something to send (see __vector_22) ---
    ldi     temp_16, CTRLA_RX_ONLY
    sts     USART0_CTRLA, temp_16

    ; CTRLC defaults to async 8N1 at reset, so no write needed for that here.
    ret

; --------------------------------------------------------------------
;  char_write - queue the byte in r24 for transmission
;
;  Returns as soon as the byte is in tx_buf; the DRE ISR does the
;  actual sending. Only blocks when the ring is full, and then only
;  until the ISR drains one slot.
;
;  DEADLOCK WARNING: that wait needs the DRE ISR to be running. Calling
;  char_write with interrupts disabled (before sei, or inside another
;  ISR) works until the 31st queued byte and then hangs forever.
; --------------------------------------------------------------------
.global char_write
char_write:
    push    temp_17
    push    tasks_26                ; X lo
    push    tasks_27                ; X hi

    lds     temp_16, tx_head        ; index this byte goes into
    mov     temp_17, temp_16
    inc     temp_17
    andi    temp_17, TX_MASK        ; temp_17 = next head

    ; --- wait while full (next head == tail) ---
1:  lds     tasks_26, tx_tail
    cp      temp_17, tasks_26
    breq    1b

    ; --- store tx_buf[head] = r24 ---
    ldi     tasks_26, lo8(tx_buf)
    ldi     tasks_27, hi8(tx_buf)
    add     tasks_26, temp_16       ; X = &tx_buf[head]
    adc     tasks_27, r1            ; r1 == 0 (zero register)
    st      X, char_24
    sts     tx_head, temp_17        ; publish the new head

    ; --- make sure the DRE ISR is running to drain it ---
    ;     Harmless if it already was: a DRE interrupt on an empty ring
    ;     just switches DREIE back off.
    ldi     temp_16, CTRLA_RX_TX
    sts     USART0_CTRLA, temp_16

    pop     tasks_27
    pop     tasks_26
    pop     temp_17
    ret

; --------------------------------------------------------------------
;  word_write - queue a word (passed in r25/r24, per AVR-GCC ABI),
;               high byte first
; --------------------------------------------------------------------
.global word_write
word_write:
    push    char_24
    mov     char_24, r25
    rcall   char_write
    pop     char_24
    rcall   char_write
    ret

; --------------------------------------------------------------------
;  flash_write - queue a zero-terminated string from FLASH (Z points to it)
;              Uses lpm with post-increment, like the tiny13 LPM pattern.
;              char_write preserves Z, so the loop pointer survives.
; --------------------------------------------------------------------
.global flash_write
flash_write:
1:
    lpm     char_24, Z+                 ; load next char from flash, advance Z
    cpi     char_24, 0                  ; null terminator?
    breq    2f                      ; yes -> done
    rcall   char_write                 ; no  -> queue it
    rjmp    1b
2:
    ret

; --------------------------------------------------------------------
;  char_read - return the oldest buffered byte in r24
;
;  Waits if the RX buffer is empty. Use char_available first when the
;  mainline has other work to do -- that is the whole point of this
;  version over serial.S.
; --------------------------------------------------------------------
.global char_read
char_read:
    push    temp_17
    push    tasks_26                ; X lo
    push    tasks_27                ; X hi

    ; --- wait while empty (head == tail) ---
1:  lds     temp_16, rx_tail
    lds     temp_17, rx_head
    cp      temp_16, temp_17
    breq    1b

    ; --- take rx_buf[tail] ---
    ldi     tasks_26, lo8(rx_buf)
    ldi     tasks_27, hi8(rx_buf)
    add     tasks_26, temp_16       ; X = &rx_buf[tail]
    adc     tasks_27, r1            ; r1 == 0 (zero register)
    ld      char_24, X
    inc     temp_16
    andi    temp_16, RX_MASK
    sts     rx_tail, temp_16        ; release the slot

    pop     tasks_27
    pop     tasks_26
    pop     temp_17
    ret

; --------------------------------------------------------------------
;  char_available - how many bytes are waiting in rx_buf, returned in r24
;                   (0 = none, so it doubles as a "would char_read block?"
;                   test). No cli needed: head is written by the ISR as a
;                   single byte, so this read cannot catch a half-update.
; --------------------------------------------------------------------
.global char_available
char_available:
    lds     char_24, rx_head
    lds     temp_16, rx_tail
    sub     char_24, temp_16
    andi    char_24, RX_MASK
    ret

; --------------------------------------------------------------------
;  flush_serial - wait until every queued byte has left the transmitter
;
;  Two waits: first for the ring to drain into the USART, then for the
;  last frame to finish shifting out (the DRE ISR clears TXCIF before
;  each write, so TXCIF set here means the final stop bit is done).
;
;  Call this before a reset, a sleep, or a clock change -- anything that
;  would cut a half-sent character short.
;
;  NOTE: needs at least one byte to have been sent since reset, or TXCIF
;  has never been set and the second loop waits forever.
; --------------------------------------------------------------------
.global flush_serial
flush_serial:
1:  lds     temp_16, tx_head        ; wait for the ring to empty
    lds     temp_17, tx_tail
    cp      temp_16, temp_17
    brne    1b
2:  lds     temp_16, USART0_STATUS  ; wait for the last frame to shift out
    sbrs    temp_16, USART_TXCIF_bp
    rjmp    2b
    ret

; ====================================================================
;  DATA / BSS
; ====================================================================
.section .data

.section .bss

; Ring buffers and their indices. Each index is written by exactly one
; side -- head by the producer, tail by the consumer -- which is what
; makes a single-byte read of the other side's index safe without cli.
rx_buf:     .skip   RX_SIZE     ; filled by __vector_21, drained by char_read
rx_head:    .skip   1           ; written by the ISR only
rx_tail:    .skip   1           ; written by the mainline only

tx_buf:     .skip   TX_SIZE     ; filled by char_write, drained by __vector_22
tx_head:    .skip   1           ; written by the mainline only
tx_tail:    .skip   1           ; written by the ISR only
