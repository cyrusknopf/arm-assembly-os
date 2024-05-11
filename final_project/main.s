; Project - Keyboard Organ with Chords
; 09/05/2024
;
; My project aims to make a keyboard organ that provides more possible
; notes than a standard implentation. Pressing multiple keys increases
; frequencies and allows for a wide range of notes when different 
; combinations of keys are experimented with.
; The approximate frequency produced by the buzzer at any given time is
; displayed on the LCD.

INCLUDE headers.s

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        B SYS_START             ; Reset
        NOP                     ; Undefined instruction
        B SVC_ENTRY             ; SVC calls
        NOP                     ; Prefetch abort
        NOP                     ; Data abort
        NOP                     ; - - - 
        B SERVICE_IRQ           ; Interrupt service
        B SERVICE_FIQ           ; Fast interrupt service

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SYS_START
    	ADRL SP, SUP_STACK_END	; Initialise supervisor stack

        LDR R5, =BUZZER         ; Load buzzer address
        LDR R3, =BUZZER_OFF     ; Set disable
        STRB R3, [R5, #1]       ; Store back to control reg

        LDR R5, =KEY_INF        ; Load address of key information
        MOV R3, #0x0            ; Initialise all keys as not pressed
        LDR R0, =NUM_KEYS       ; R0 points to each location in the loop
LOOP3
        STRB R3, [R5, R0]       ; Initialise the counter for digit R0 to 0x0
        SUBS R0, R0, #0x1       ; Decrement loop pointer
        BNE LOOP3               ; Next location

        LDR LR, =IRQ_FLAGS      ; Set flags for IRQ mode (with interrupts disabled (bits 7,6 high))
        MSR CPSR, LR            ; Enter IRQ mode
        ADRL SP, ITR_STACK_END  ; Initialise interrupt stack

        LDR R3, =ITRPT_EN       ; Load address to enable device interrupts
        LDR R4, =TIMER_IRQ_BIT  ; Only enable timer compare interrupt
        STRB R4, [R3]           ; Store to address

        LDR R3, =ITRPT          ; Load the address of the interrupt bits
        MOV R4, #0x0            ; Clear all interrupts for now
        STRB R4, [R3]           ; Store to address

        LDR R9, =TIMER_COMP     ; Load address of the timer compare interrupt
        LDR R8, =TIMER_PERIOD   ; Set the 'time' before next interrupt (1 tick in this case)
        STRB R8, [R9]           ; Store that to the address containing timer compare value

        LDR R11, =FRONTL_PORT   ; Load addres of front left port (data reg, control reg = data + 1)
        LDR R4, =KPAD_CTRL      ; Set control to input
        STRB R4, [R11, #1]      ; Store to control register of the left port

        LDR R10, =PORTA         ; Load address of port A of LCD

        LDR LR, =USR_FLAGS      ; Set status flags for user mode (with interrupts enabled)
        MSR SPSR, LR            ; Move status to SPSR
        ADR LR, USR_START       ; Set LR to start of user code
        MOVS PC, LR             ; Enter user code

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

USR_START
        B .                     ; The "user" of my program is in real life, not in software

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Scans the keyboard column by column. Column is specified by R0.
; Corrupts: R0

SCAN_KEYS
        PUSH {LR}               ; Save call point

        LDR R0, =COL_ONE        ; Column: 1,4,7
        BL SCAN_COL             ; Scan the column

        LDR R0, =COL_TWO        ; Column: 2,5,8,0
        BL SCAN_COL             ; Scan the column

        LDR R0, =COL_THREE      ; Column: 3,6,9
        BL SCAN_COL             ; Scan the column

        BL CHECK_BUZZER

        POP {PC}                ; Return
        
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Scans the "R0"th column, where R0 = 0x1 scans the column 3,6,9; R0 = 0x2 scans 
; the column with 2,5,8,0; etc.
; Corrupts: R1, R11

SCAN_COL
        PUSH {LR}               ; Save call address

        LDR R11, =FRONTL_PORT   ; Load addres of front left port (data reg, control reg = data + 1)
        MOV R1, #0x1            ; Store 1 into R1
        LSL R1, R1, R0          ; Shift to get highest 4 bit value of data reg
        LSL R1, R1, #4          ; Shift to make them the upper 4 bits; lower 4 zero

        BL DISABLE_COL          ; Set all the addresses for this column to 0, pressed keys will reset
        SVC CLEAR_LCD           ; Clear the LCD of any previous display, ready to (possibly) reprint

        STRB R1, [R11]          ; Store to scan a given column

        LDRB R1, [R11]          ; Load the value of the column

        ANDS R1, R1, #0xF       ; If the lower four bits are 0...
        POPEQ {PC}              ; ... then no key pressed, return
        
        ; If we are here, there is a key being pressed...
        
        MOV R8, #0b10000        ; Create a mask to check the each digit (not aliased for clarity)
        MOV R7, R0              ; Copy the original value
        MOV R9, R1              ; Copy the original value
NEXT_KEY
        LSRS R8, R8, #1         ; Shift right to check next digit. If zero...
        POPEQ {PC}              ; ... then done checking, return. Else check this digit
        MOV R0, R7              ; Restore initial value
        MOV R1, R9              ; Restore initial value
        ANDS R1, R1, R8         ; AND with mask to only check a single digit. If zero...
        BEQ NEXT_KEY            ; ... no need to update this key as it is not pressed. Next key.
        BL TRANSL_DIGIT         ; Translate the reading from port to digit
        BL UPDATE_KEY           ; Update the addresses to denote keys are pressed
        B NEXT_KEY

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Using the column specified in R1, resets all the keys in that column to an "unpressed"
; state in memory
; Corrupts: R2, R3

DISABLE_COL
        PUSH {LR}               ; Save call point
        
        LDR R2, =KEY_INF        ; Load the address where the information about keys is stored

        CMP R1, #COL_ONE_MEM    ; If we are clearing column 1... then do nothing.

        CMP R1, #COL_TWO_MEM    ; If we are clearing column 2...
        ADDEQ R2, R2, #1        ; Then offset the addresses by 1. (1=2,4=5,7=8, etc)

        CMP R1, #COL_THREE_MEM  ; If we are clearing column 3...
        ADDEQ R2, R2, #2        ; Then offset the addresses by 2. (1=3,4=6,7=9, etc)

        MOV R3, #0x0            ; R3 to 0 to clear the addresses
        STRB R3, [R2, #0x1]     ; Clear key 1/2/3
        STRB R3, [R2, #0x4]     ; Clear key 4/5/6
        STRB R3, [R2, #0x7]     ; Clear key 7/8/9
        STRB R3, [R2, #0xa]     ; Clear key */0/#

        POP {PC}                ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Checks the memory addresses which contains the info for if keys are pressed.
; Handles enabling or disabling of the buzzer
; Corrupts: R4, R0, R3

CHECK_BUZZER
        PUSH {LR}               ; Save call point

        MOV R4, #0x0            ; Use R0 to track which keys are being pressed
        LDR R0, =NUM_KEYS       ; R0 points to each location in the loop, from 12 to 0
LOOP4
        LDRB R3, [R5, R0]       ; Initialise the counter for digit R0 to 0x80
        MUL R3, R3, R0          ; Get R3 (0/1) * R0 (number) = 0 if not pressed or the number if yes
        ADD R4, R4, R3          ; Sum this to the running total
        SUBS R0, R0, #0x1       ; Increment loop pointer
        BNE LOOP4               ; Next location
CONT2
        CMP R4, #0x1            ; If non-zero...
        BGE ENABLE_BUZZER       ; ... then some key is being pressed. Turn on buzzer...
        B DISABLE_BUZZER        ; ... else, no key pressed disable buzzer

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Stores 0xFE to the control register of the buzzer to enable it
; Corrupts: R5, R1

ENABLE_BUZZER

        LDR R5, =BUZZER         ; Load the address of the buzzer 
        STRB R4, [R5]           ; Store the value denoting what keys are pressed to the data reg
        LDR R1, =BUZZER_ON      ; Set enable
        STRB R1, [R5, #1]       ; Store enable

        SVC PRINT_FREQUENCY     ; Display the frequency on the LCD

        POP {PC}                ; Return the call point which was saved by CHECK_BUZZER

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Stores 0xFF to the control register of the buzzer to disable it
; Corrupts: R5, R1

DISABLE_BUZZER

        LDR R5, =BUZZER         ; Load buzzer address
        LDR R1, =BUZZER_OFF     ; Set FF to turn off
        STRB R1, [R5, #1]       ; Store back

        POP {PC}                ; Return the call point which was saved by CHECK_BUZZER

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Using the decimal digit stored in R0, sets the address of the key info address,
; offset by R0, to 1
; Corrupts: R1, R2

UPDATE_KEY
        PUSH {LR}               ; Save call point

        LDR R2, =KEY_INF        ; Load key info address

        MOV R1, #1              ; Set 1 in R1
        STRB R1, [R2, R0]       ; Store back to address

        POP {PC}                ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Using values stored in R1 (row)  and R0 (column) , translates the keypad reading into
; the corresponding decimal digit
; Returns the decimal digit in R0
; Corrupts: R1

TRANSL_DIGIT
        PUSH {LR}               ; Save call point

        RSB R0, R0, #0x4        ; Store (4 - R0) into R0. Used to get correct digit

LOOP
        LSR R1, R1, #0x1        ; R1 = (number of times we need to add 3) x 2

        CMP R1, #0              ; If R1 is zero...
        POPEQ {PC}              ; ... then return...
        ADD R0, R0, #0x3        ; ... else, add 3 to R0...
        B LOOP                  ; ... and loop.
        
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Using the keys that are pressed in R4, prints the frequency of the current note
; to the LCD. THIS IS AN APPROXIMATION, as the actual frequency is calculated in hardware
; using a clock divider to first get a 1MHz clock, and then divided again using the same
; calculation method. This division from 1,000,000Hz to the actual frequency is not possible
; (easily) in software so I use an integer division approximation. Serves purpose and gives
; reasonable feedback on the LCD. As mentioned in PIOBuzzer.v, the calculation is arbitary
; but produces pleasant results for this keyboard and buzzer.
;
; The approximate and precise calculation in software and hardware, respectively, is:
; note freq = 1,000,000 / (NOTE_CONSTANT - (sum of pressed keys * NOTE_MULTIPLIER)
;
; Corrupts: R5, R4, R0

PRINT_FREQ
        LDR R5, =NOTE_MULTIPLIER; We multiply the value of the keys pressed by a constant
        MUL R4, R5, R4          ; Keys pressed * constant (R5)
        RSBS R4, R4, #NOTE_CONSTANT; Normalise to get a good value to be divided by 1mil to give note
        LDRMI R4, =BACKUP_FREQ  ; In the case that the dividend becomes negative
        LDR R1, =ONE_MILLION    ; Load 1 million i.e. 1GHz which is used in my verilog divider
        BL INTEGER_DIVIDE       ; Approximate 1 000 000 / R4
        
        BL GET_DIGITS           ; Calculate and print the digits in decimal

        MOV R0, #'H'            ; ASCCI of 'H'
        BL PRINT_CHAR           ; Print it
        MOV R0, #'z'            ; ASCII of 'z'
        BL PRINT_CHAR           ; Print it
        
        B SVC_RETURN            ; Exit out of SVC call safely
         
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Performs division and prints the decimal digits of the number stored in R0
; to the LCD

GET_DIGITS
        PUSH {LR}               ; Save call point
        MOV R12, #0             ; Initialise our digit counter to 0
GET_DIGIT
        ADD R12, R12, #&1       ; We have a digit, increment
        BL DIV_TEN              ; Perform division. R0 <- quotient, R1 <- remainder
        PUSH {R1}               ; Push remainder
        CMP R0, #&0             ; If the result of division is not 0...
        BNE GET_DIGIT           ; ... then divide again
PRINT_DIGIT
        CMP R12, #&0            ; If we have no more digits to print...
        POPEQ {PC}              ; Return
        SUB R12, R12, #&1       ; Subtract 1 to denote we have printed a digit
        POP {R0}                ; Put remainder into R0 for printing
        ADD R0, R0, #'0'        ; ASCIIfy
        BL PRINT_CHAR           ; Print the digit
        B PRINT_DIGIT           ; Again
        
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Division by ten. R0 / 10 -> R0: Quotient, R1: Remainder
;
; This method of division uses "divide by multiply" which I discovered here:
; https://stackoverflow.com/questions/19844575/how-to-do-division-in-arm
;
; My modified version uses an approximation of 1/10 * 2^32. As per the ARM
; documentation: 
;
; https://developer.arm.com/documentation/dui0489/i/arm-and-thumb-instructions/umull
; The `UMULL` instruction places the higher 32 bits of the result in the second
; provided regisiter (R0 here). Due to the scaling back to 32 bit registers, this
; yields the required dividend (assuming the numbers we are dividing are at most 4
; digits as per specification, this approximation is sufficient).

DIV_TEN
        PUSH {LR}               ; Save callpoint
        PUSH {R2}               ; Save R2
        PUSH {R0}               ; Save dividend
        MOV R1, R0              ; Copy dividend into R1
        LDR R2, =ONE_OVER_TEN   ; Move reciprocal of 10 to R2
        UMULL R1, R0, R1, R2    ; Multiply R1 by reciprocal, R0 containing LSBs
        
        MOV R1, R0              ; Copy quotient to R1
        MOV R2, #10             ; Load 10 for later multiplication
        MUL R1, R1, R2          ; Quotient * 10 = R0 `div` 10
        
        POP {R2}                ; Put original dividend (R0) to R2
        SUB R1, R2, R1          ; dividend - (dividend `div` 10) = (dividend `mod` 10) i.e. remainder
        POP {R2}                ; Restore the orginal value back to R2

        POP {LR}                ; Restore return location
        MOV PC, LR              ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; R0 = R1 // R4

INTEGER_DIVIDE
        PUSH {LR}               ; Save call point

WHILE
        SUBS R1, R1, R4         ; Dividend - divisor
        ADD R0, R0, #1          ; R0 stores the quotient
        BPL WHILE               ; While our value is still positive (i.e. not fully divided) loop

        ; On average we will divide once more than necessary (in order to use SUBS I check for
        ; negative values when looping)
        SUB R0, R0, #1          ; Minus 1 one to counteract the extra division

        POP {PC}                ; Return 

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Prints the ASCII character whose code is the value stored in R0 the LCD
; Corrupts: R2

PRINT_CHAR
        PUSH {LR}               ; Save call point
        LDR R10, =PORTA         ; Store the LCD port address to R10
        BL ENABLE_LCD           ; Enable the LCD backlight
        BL CHECK_LCD_IDLE       ; Check LCD is available to access

        AND R2, R2, #LCD_WR_EN  ; Set bit 2 low to enable write
        STRB R2, [R10, #4]      ; Store back to Port B
        
        ORR R2, R2, #LCD_BUS_OUT; Set bit 1 high to set bus output
        STRB R2, [R10, #4]      ; Store back to Port B

        STRB R0, [R10]          ; Put ASCII char onto data bus

        ORR R2, R2, #LCD_BUS_EN ; Set bit 0 high to enable bus
        STRB R2, [R10, #4]      ; Store back to Port B

        AND R2, R2, #LCD_BUS_DI ; Set bit 0 low to disable bus
        STRB R2, [R10, #4]      ; Store back to Port B

        POP {PC}                ; Return
	
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Enable the LCD backlight. Assumes R10 contains the LCD port address
; Corrupts: R2

ENABLE_LCD
        LDRB R2, [R10, #4]      ; Load value of Port B
        ORR R2, R2, #LCD_EN     ; Set bit 5 high to enable LCD
        STRB R2, [R10, #4]      ; Store back to Port B
        MOV PC, LR              ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Check if LCD is accesible. Assumes R10 contains the LCD port address
; Corrupts: R2, R3

CHECK_LCD_IDLE
        LDRB R2, [R10, #4]      ; Load value of Port B
        ORR R2, R2, #&4         ; Set bit 3 high to enable read
        STRB R2, [R10, #4]      ; Store back to Port B
        
        AND R2, R2, #LCD_CTRL_EN; Set bit 1 low to set control
        STRB R2, [R10]          ; Store back to Port B

        ORR R2, R2, #LCD_BUS_EN ; Set bit 1 high to enable bus
        STRB R2, [R10, #4]      ; Store back to Port B

        LDRB R3, [R10]          ; Read LCD status byte from Port A

        LDRB R2, [R10, #4]      ; Load value of Port B

        AND R2, R2, #LCD_BUS_DI ; Set bit 0 low to disable bus
        STRB R2, [R10, #4]      ; Store back to Port B
        
        AND R3, R3, #&80        ; Set bits 0-6 low of value from Port A
        CMP R3, #&80            ; If bit 7 is high...
        BEQ CHECK_LCD_IDLE      ; ... then go back to check again...
        MOV PC, LR              ; ... else return.

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Clears the LCD screen

CLEAR_SCREEN
        LDR R10, =PORTA         ; LCD Port A loaded

        LDRB R2, [R10, #4]      ; Load the value of Port B
        AND R2, R2, #&0         ; Set Read/Write (and eveything else) low
        STRB R2, [R10, #4]      ; Store back to Port B
        
        MOV R2, #&1             ; Set all bits low except bit 0
        STRB R2, [R10]          ; Store to Port A
        
        STRB R2, [R10, #4]      ; Enable bus

        AND R2, R2, #LCD_BUS_DI ; Disable bus
        B SVC_RETURN            ; Exit from the supervisor call

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Increments the value which the timer compare uses to interrupt
; Corrupts: R8, R9

INCR_COMP
        PUSH {LR}               ; Save callpoint 

        LDR R9, =TIMER_COMP     ; Load the address of the compare value
        LDRB R8, [R9]           ; Load the value currently in compare
        ADD R8, R8, #0x01       ; Increment compare value to 
        CMP R8, #TIM_MAX        ; If the compare is greater than hardware timer max...
        ANDGT R8, R8, #0xFF     ; ... then normalise
        STRB R8, [R9]           ; Store back to clock compare
        
        POP {PC}                ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Service interrupts. Only one source so primitive checking. Acknowledges that device

SERVICE_IRQ
        SUB LR, LR, #4          ; Correct return address
        PUSH {R0-R3, R5, R7-R11, LR}        ; Save return address and user registers

        LDR R3, =ITRPT          ; Load the adddress containing the interrupt bits
        LDR R7, [R3]            ; Load that value

        ; This is primitive as I only expect to see an interrupt from bit 1 (timer)
        CMP R7, #TIMER_IRQ_BIT  ; If that value is 1, that means the timer is interrupting...
        BEQ HANDLE_TIMER_IRQ    ; ... handle it
        B EXIT_SERVICE          ; Otherwise, the timer isnt interrupting, exit 

        
HANDLE_TIMER_IRQ
        BIC R7, R7, #TIMER_IRQ_BIT
        STRB R7, [R3]
        BL INCR_COMP            ; Increment timer compare
        BL SCAN_KEYS            ; Scan keys and print as necessary

EXIT_SERVICE
        POP {R0-R3, R5, R7-R11, PC}^; Restore registers and return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SERVICE_FIQ
        SUB LR, LR, #4          ; Correct return address
        PUSH {LR}               ; Save return address

        POP {PC}^               ; Restore registers and return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Calculates the SVC number to jump to by referencing the instruction which called it
SVC_ENTRY
        PUSH {LR}               ; Push instruction AFTER SVC call onto stack
        LDR LR, [LR, #-4]       ; Load instruction BEFORE that pointed by LR, i.e. SVC instruction
        BIC LR, LR, #0xFF000000 ; Clear 8 MSBs, leaving 24 bit number passed to SVC (raw for clarity)

        ; Dynamic SVC range checking:
        LDR R8, =JUMP_TABLE     ; Load address of SVC table
        LDR R7, =JUMP_TABLE_END ; Load address of the end of the table
        SUB R8, R7, R8          ; Calculte the difference
        LSR R8, R8, #2          ; Divide by 4 to get number of addresses
        SUB R8, R8, #1          ; Subtract one since table is 0 indexed

        CMP LR, R8              ; If SVC number is out of range...
        BHI .                   ; ... then end...
        ADR R12, JUMP_TABLE     ; ... else then store jump table address in R11...
        LDR PC, [R12, LR, LSL #2]; LR LSL 2 = LR * 2 => For SVC x we have JUMP_TABLE + 4x

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Returns to callpoint and resets flags
SVC_RETURN
        POP {LR}                ; Restore call point
        MOVS PC, LR             ; Return and set flags

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

JUMP_TABLE
        DEFW PRINT_FREQ
        DEFW CLEAR_SCREEN
        ; ... 
JUMP_TABLE_END

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ALIGN                           ; Ensures stacks are word aligned
SUP_STACK DEFS STACK_SIZE       ; Stack for supervisor mode
SUP_STACK_END                   ; For static initialisation of SP
ITR_STACK DEFS STACK_SIZE       ; Stack for interrupt requests
ITR_STACK_END                   ; For static initialisation of SP
