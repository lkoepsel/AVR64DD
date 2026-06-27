; ====================================================================
;  ; AVR64DD32 
;       init_serial   - configure USART0 on the Curiosity Nano CDC pins
;       char_write       - transmit one byte (in r24), blocking
;       word_write       - transmit two bytes (in r25/r24), blocking
;       flash_write     - transmit a zero-terminated string (Z -> flash)
;       char_read       - receive one byte (returns in r24), blocking
; Target : AVR64DD32 (Curiosity Nano)
; Clock  : see F_CPU note below -- baud value depends on it
; Toolchain: avr-as / avr-ld  (GNU Binutils for AVR)
;
;  The Curiosity Nano wires the USB CDC virtual COM port to USART0:
;       PD4 = USART0 TX,  PD5 = USART0 RX
;  BUT these are USART0's ALTERNATE pins, so PORTMUX must route USART0
;  to them. Skipping the PORTMUX step is the #1 cause of "no output".
;
;  On the RPi, the port appears as /dev/ttyACM0 (or ACM1). Talk to it with:
;       tio /dev/ttyACM0        (or screen / picocom), 8N1, baud below.
; ====================================================================

#include <avr/io.h>

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

; ====================================================================
;  TEXT SECTION
; ====================================================================
.section .text

; ---------- Registers and Values ----------------
; r24                           ; char register - byte to send / received byte
; r16                           ; temp register - scratch
; Z (Z_31_hi:Z_30_lo)                   ; flash pointer for flash_write

; --------------------------------------------------------------------
;  init_serial - set up USART0 on PD4/PD5 via PORTMUX, 8N1, TX+RX enabled
; --------------------------------------------------------------------
.global init_serial
init_serial:
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

    ; CTRLC defaults to async 8N1 at reset, so no write needed for that here.
    ret

; --------------------------------------------------------------------
;  char_write - send the byte in r24, waiting until the data register is free
; --------------------------------------------------------------------
.global char_write
char_write:
    ; --- wait for DREIF (data register empty) in USART0.STATUS ---
1:
    lds     temp_16, USART0_STATUS
    sbrs    temp_16, USART_DREIF_bp     ; skip next when DRE flag set (ready)
    rjmp    1b
    ; --- write the byte; this clears DREIF and starts transmission ---
    sts     USART0_TXDATAL, char_24
    ret
; --------------------------------------------------------------------

; write a word (passed in r25/r24, per AVR-GCC ABI) to the serial port
.global word_write
word_write:
    push    char_24
    mov     char_24, r25
    rcall   char_write
    pop     char_24
    rcall   char_write
    ret


; --------------------------------------------------------------------
;  flash_write - send a zero-terminated string from FLASH (Z points to it)
;              Uses lpm with post-increment, like the tiny13 LPM pattern.
; --------------------------------------------------------------------
.global flash_write
flash_write:
1:
    lpm     char_24, Z+                 ; load next char from flash, advance Z
    cpi     char_24, 0                  ; null terminator?
    breq    2f                      ; yes -> done
    rcall   char_write                 ; no  -> send it
    rjmp    1b
2:
    ret

; --------------------------------------------------------------------
;  char_read - block until a byte arrives, return it in r24
; --------------------------------------------------------------------
.global char_read
char_read:
    ; --- wait for RXCIF (receive complete) in USART0.STATUS ---
1:
    lds     temp_16, USART0_STATUS
    sbrs    temp_16, USART_RXCIF_bp     ; skip when receive-complete flag set
    rjmp    1b
    ; --- read the received byte (clears RXCIF) ---
    lds     char_24, USART0_RXDATAL
    ret

; ====================================================================
;  DATA / BSS
; ====================================================================
.section .data
.section .bss
