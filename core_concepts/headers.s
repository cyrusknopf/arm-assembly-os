; LCD Ports
PORTA           EQU &10000000
PORTB           EQU &10000004
; Timer compare value
TIMER_COMP      EQU &1000000C
; Hardware timer value
TIMER           EQU &10000008
; My software timer
MY_TIMER        EQU &400
; Interrupt bits
ITRPT           EQU &10000018
; Interrupt enable
ITRPT_EN        EQU &1000001C
; Bottom Left Port: Data Register, Control register at address + 1
FRONTL_PORT     EQU &20000002
; Debounce info
DB_INF          EQU &500
