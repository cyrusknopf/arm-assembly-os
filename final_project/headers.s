; ADDRESSES

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
KEY_INF         EQU &600
; Buzzer data, Control reg at +1
BUZZER          EQU &20000000

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; ALIASES

TIM_MAX         EQU &100

; Setup
BUZZER_OFF      EQU &FF
BUZZER_ON       EQU &FE
NUM_KEYS        EQU &C
IRQ_FLAGS       EQU &D2
TIMER_IRQ_BIT   EQU &1
TIMER_PERIOD    EQU &1
KPAD_CTRL       EQU &1F
USR_FLAGS       EQU &10
STACK_SIZE      EQU &80

; Keypad info
COL_ONE         EQU &3
COL_ONE_MEM     EQU &80

COL_TWO         EQU &2
COL_TWO_MEM     EQU &40

COL_THREE       EQU &1
COL_THREE_MEM   EQU &20

NUM_KEYS        EQU &C
COL_SIZE        EQU &4

; Frequency calculations
NOTE_CONSTANT   EQU &1000
NOTE_MULTIPLIER EQU &40
BACKUP_FREQ     EQU &800
ONE_MILLION     EQU &F4240

; Decimal printing
ONE_OVER_TEN    EQU &1999999A

; LCD control
LCD_WR_EN       EQU &FB
LCD_BUS_OUT     EQU &2
LCD_BUS_EN      EQU &1
LCD_BUS_DI      EQU &FE
LCD_EN          EQU &20
LCD_CTRL_EN     EQU &FD

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; SVC ALIASES

PRINT_FREQUENCY EQU &0
CLEAR_LCD       EQU &1
