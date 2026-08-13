; ====================================================================
;  INTERRUPT VECTOR TABLE
;
;  The table must extend to the highest vector actually used -- the two
;  USART0 entries at the bottom are the whole point here. Unused slots
;  jmp to 0 (a reset) so a stray interrupt is loud rather than silent.
; ====================================================================
.section .vectors, "ax", @progbits
    jmp     reset_handler       ; 0x000  vector 0  RESET
    jmp     0                   ; 0x004  vector 1  NMI
    jmp     0                   ; 0x008  vector 2  BOD_VLM
    jmp     0                   ; 0x00C  vector 3  CLKCTRL
    jmp     0                   ; 0x010  vector 4  MVIO_MVIO
    jmp     0                   ; 0x014  vector 5  RTC_CNT
    jmp     0                   ; 0x018  vector 6  RTC_PIT
    jmp     0                   ; 0x01C  vector 7  CCL_CCL
    jmp     0                   ; 0x020  vector 8  PORTA_PORT
    jmp     0                   ; 0x024  vector 9  TCA0_OVF
    jmp     0                   ; 0x028  vector 10 TCA0_HUNF
    jmp     0                   ; 0x02C  vector 11 TCA0_CMP0
    jmp     0                   ; 0x030  vector 12 TCA0_CMP1
    jmp     0                   ; 0x034  vector 13 TCA0_CMP2
    jmp     0                   ; 0x038  vector 14 TCB0_INT
    jmp     0                   ; 0x03C  vector 15 TCB1_INT
    jmp     0                   ; 0x040  vector 16 TCD0_OVF
    jmp     0                   ; 0x044  vector 17 TCD0_TRIG
    jmp     0                   ; 0x048  vector 18 TWI0_TWIS
    jmp     0                   ; 0x04C  vector 19 TWI0_TWIM
    jmp     0                   ; 0x050  vector 20 SPI0_INT
    jmp     __vector_21         ; 0x054  vector 21 USART0_RXC  (byte arrived)
    jmp     __vector_22         ; 0x058  vector 22 USART0_DRE  (ready to send)
