; My implementation uses a byte to represent the state of each key
; All states are initialised to 0x80
; Every interrupt, all states are shifted left one digit up to a maximum of 0x80
; Every interrupt, if a key is recognised as pressed, AND its state is 0x80, it is
; printed on the LCD and its state is shifted two bits right. This means each
; interrupt, a held key has the state 0x40.
; If a key which was previously pressed is let go of, the standard `SHIFT_BACK` will
; return its state from 0x40 to 0x80, meaning the next time it is pressed it will print again
; If a key is registered as pressed and its state is less than 0x80, then it is a repeated press
; (i.e. a bounce), its state is shifted right to prevent it from reprinting

include headers.s

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
	ADR SP, SUP_STACK	; Initialise supervisor stack
	ADD SP, SP, #0x40	; Initialise supervisor stack pointer

        LDR R5, =DB_INF         ; Load address of debounce information
        MOV R3, #0x80           ; 80 to initialise all debounce counters
        MOV R0, #0x0            ; R0 points to each location in the loop
LOOP3
        CMP R0, #0xA            ; 9 bytes, stop once we reach 10
        BEQ CONT                ; Once reach 10, break
        STRB R3, [R5, R0]       ; Initialise the counter for digit R0 to 0x80
        ADD R0, R0, #0x1        ; Increment loop pointer
        B LOOP3                 ; Next location
CONT
        MOV LR, #0xD2           ; Set flags for IRQ mode (with interrupts disabled (bits 7,6 high))
        MSR CPSR, LR            ; Enter IRQ mode
        ADR SP, ITR_STACK       ; Initialise interrupt stack
        ADD SP, SP, #40         ; Initialise interrupt stack pointer

        LDR R3, =ITRPT_EN       ; Load port to enable device interrupts
        MOV R4, #0x01           ; Only enable timer compare interrupt
        STRB R4, [R3]           ; Store to port

        LDR R9, =TIMER_COMP     ; Load address of the timer compare interrupt
        MOV R8, #0x1            ; We will interrupt once the timer reaches 10
        STRB R8, [R9]           ; Store that to the address containing timer compare value

        LDR R11, =FRONTL_PORT   ; Load addres of front left port (data reg, control reg = data + 1)
        MOV R4, #0x1F           ; Set control to input
        STRB R4, [R11, #1]      ; Store to control register of the left port

        LDR R10, =PORTA         ; Load address of port A of LCD

        MOV LR, #0x10           ; Set status flags for user mode (with interrupts enabled)
        MSR SPSR, LR            ; Move status to SPSR
        ADR LR, USR_START       ; Set LR to start of user code
        MOVS PC, LR             ; Enter user code

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

USR_START
        B .                     ; TODO Implement user program here

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Scans the keyboard column by column. Column is specified by R0.
; Corrupts: R0

SCAN_KEYS
        PUSH {LR}               ; Save call point

        MOV R0, #0x3            ; Column: 1,4,7
        BL SCAN_COL             ; Scan the column

        MOV R0, #0x2            ; Column: 2,5,8,0
        BL SCAN_COL             ; Scan the column

        MOV R0, #0x1            ; Column: 3,6,9
        BL SCAN_COL             ; Scan the column

        BL SHIFT_BACK           ; Reduce the debounce counter for all keys
        
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

        STRB R1, [R11]          ; Store to scan a given column

        LDRB R1, [R11]          ; Load the value of the column

        TST R1, #0xF            ; If the lower four bits are 0...
        POPEQ {PC}              ; ... then no key pressed, return
        
        ; If we are here, there is a key being pressed...
        AND R1, R1, #0x0F       ; Isolate lower 4 bits for translation
        
        BL TRANSL_DIGIT         ; Translate the reading from port to digit

        BL DEBOUNCE             ; Update the debounce for the key

        POP {PC}                ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Shifts all keys debounce counter left one place
; Corrupts: R0, R5, R7

SHIFT_BACK
        PUSH {LR}               ; Save callpoint

        LDR R5, =DB_INF         ; Load address of debounce information
        MOV R0, #0x0            ; Loop variable to update all memory locations
LOOP2
        CMP R0, #0xA            ; 9 Memory locations to update, stop once we reach 10
        POPEQ {PC}              ; Return
        
        LDRB R7, [R5, R0]       ; Load the value in the address of R5 + digit
        CMP R7, #0x40           ; If the debounce counter is 0x40 or less...
        LSLLS R7, R7, #0x1      ; ... shift left one place. This shifts the value to at most 0x80
        STRB R7, [R5, R0]       ; Store back to memory
        ADD R0, R0, #0x1        ; Increment loop var to point to next location
        B LOOP2                 ; Next iteration

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Rotates the decimal digit in R0's debounce counter three digits right. Prints the
; digit if it has been pressed long enough
; Corrupts: R5, R7

DEBOUNCE
        PUSH {LR}               ; Save call point

        LDR R5, =DB_INF         ; Load address of debounce information
        LDRB R7, [R5, R0]       ; Load the value in the address of R5 + digit

        CMP R7, #0x80           ; If the state is untouched...
        BEQ BOUNCED             ; ... then this is the first time the key is pressed: print.

        ; If we are here, the value is less than 0x80, meaning the key was recently pressed
        ROR R7, R7, #0x1        ; Rotate debounce counter right 1 digit
        STRB R7, [R5, R0]       ; Store back to the digit counter
        POP {PC}                ; Return

BOUNCED
        ROR R7, R7, #0x2        ; Rotate right twice to prevent it to returning to 0x80 while held
        STRB R7, [R5, R0]       ; Store back to the digit counter
        BL DISPLAY_DIG          ; Print digit to LCD
        POP {PC}                ; Return

 ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Converts the decimal digit in R0 to ASCII and displays the digit on the LCD
; Corrupts: R0

DISPLAY_DIG
        PUSH {LR}               ; Save call point
        ADD R0, R0, #0x30       ; ASCIIfy the digit stored in R0
        BL PRINT_CHAR           ; Print the digit stored in R0
        POP {PC}                ; Return

 ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Using values stored in R1 (row)  and R0 (column) , translates the keypad reading into
; the corresponding decimal digit
; Returns the decimal digit in R0
; Corrupts: R1

TRANSL_DIGIT
        PUSH {LR}               ; Save call point

        ; HANDLING EDGE CASE: My normal translation dose not work for the "0" key
        ; As such, we check for if R1 is 8, which is only the case if "0" key is pressed,
        ; and return accordingly
        CMP R1, #0x8            ; Edge case: 0 digit pressed
        MOVEQ R0, #0x0          ; Load 0 digit to R0
        POPEQ {PC}              ; Return
        
        RSB R0, R0, #0x4        ; Store (4 - R0) into R0. Used to get correct digit

LOOP
        LSR R1, R1, #0x1        ; R1 = (number of times we need to add 3) x 2

        CMP R1, #0              ; If R1 is zero...
        POPEQ {PC}              ; ... then return...
        ADD R0, R0, #0x3        ; ... else, add 3 to R0...
        B LOOP                  ; ... and loop.
        
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Prints the ASCII character whose code is the value stored in R0
; Corrupts: R2, R10

PRINT_CHAR
        PUSH {LR}               ; Save call point
        LDR R10, =PORTA         ; Load port A address
        BL ENABLE_LCD           ; Enable the LCD backlight
        BL CHECK_LCD_IDLE       ; Check LCD is available to access

	AND R2, R2, #&FB        ; Set bit 2 low to enable write
	STRB R2, [R10, #4]      ; Store back to Port B
	
	ORR R2, R2, #&2         ; Set bit 1 high to set bus output
	STRB R2, [R10, #4]      ; Store back to Port B

        STRB R0, [R10]          ; Put ASCII char onto data bus

	ORR R2, R2, #&1         ; Set bit 0 high to enable bus
	STRB R2, [R10, #4]      ; Store back to Port B

	AND R2, R2, #&FE        ; Set bit 0 low to disable bus
	STRB R2, [R10, #4]      ; Store back to Port B

        POP {PC}                ; Return
	
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Enable the LCD backlight. Assumes R10 contains Port A address
; Corrupts: R2

ENABLE_LCD
	LDRB R2, [R10, #4]      ; Load value of Port B
	ORR R2, R2, #&20        ; Set bit 5 high to enable LCD
	STRB R2, [R10, #4]      ; Store back to Port B
        MOV PC, LR              ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Check if LCD is accesible. Assumes R10 contains Port A address
; Corrupts: R2, R3

CHECK_LCD_IDLE
        LDRB R2, [R10, #4]      ; Load value of Port B
        ORR R2, R2, #&4         ; Set bit 3 high to enable read
        STRB R2, [R10, #4]      ; Store back to Port B
        
	AND R2, R2, #&FD        ; Set bit 1 low to set control
	STRB R2, [R10]          ; Store back to Port B

	ORR R2, R2, #&1         ; Set bit 1 high to enable bus
	STRB R2, [R10, #4]      ; Store back to Port B

	LDRB R3, [R10]          ; Read LCD status byte from Port A

	LDRB R2, [R10, #4]      ; Load value of Port B

	AND R2, R2, #&FE        ; Set bit 0 low to disable bus
	STRB R2, [R10, #4]      ; Store back to Port B
	
	AND R3, R3, #&80        ; Set bits 0-6 low of value from Port A
	CMP R3, #&80            ; If bit 7 is high...
	BEQ CHECK_LCD_IDLE      ; ... then go back to check again...
        MOV PC, LR              ; ... else return.

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Increments the value which the timer compare uses to interrupt
; Corrupts: R8, R9

INCR_COMP
        PUSH {LR}               ; Save callpoint 

        LDR R9, =TIMER_COMP     ; Load the address of the compare value
        LDRB R8, [R9]           ; Load the value currently in compare
        ADD R8, R8, #0x01       ; Increment compare value to 
        CMP R8, #0xFF           ; If the compare is greater than 255 (hardware timer max)...
        SUBGT R8, R8, #0xFF     ; ... then normalise.
        STRB R8, [R9]            ; Store back to clock compare
        
        POP {PC}                ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SERVICE_IRQ
        SUB LR, LR, #4          ; Correct return address
        PUSH {R0-R3, R5, R7-R11, LR}        ; Save return address and user registers

        BL INCR_COMP            ; Increment timer compare
        BL SCAN_KEYS            ; Scan keys and print as necessary

        POP {R0-R3, R5, R7-R11, PC}^        ; Restore registers and return

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
	BIC LR, LR, #0xFF000000 ; Clear 8 MSBs, leaving 24 bit number passed to SVC

	CMP LR, #0x0            ; If SVC number is out of range...
	BHI .                   ; ... then end...
	ADR R12, JUMP_TABLE     ; ... else then store jump table address in R11...
        LDR PC, [R12, LR, LSL #2]       ; LR LSL 2 = LR * 2 => For SVC x we have JUMP_TABLE + 4x

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Returns to callpoint and resets flags
SVC_RETURN
        POP {LR}                ; Restore call point
        MOVS PC, LR             ; Return and set flags

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

JUMP_TABLE
        ; ... 

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ALIGN                           ; Ensures stacks are word aligned
SUP_STACK DEFS 256              ; Stack for supervisor mode
ITR_STACK DEFS 256               ; Stack for interrupt requests
