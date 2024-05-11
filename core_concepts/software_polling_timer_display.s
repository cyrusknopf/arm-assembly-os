; My program uses R4 to track the timer mode so they appropriate action
; can be taken on button press. Only the lowest two bits of the register
; are used:
; - Bit 0: 1 = Timer running, 0 = Timer stopped
; - Bit 1: 1 = Reset being held/pressed, 0 = Reset not being held/pressed

include headers.s

	B SYS_START
	NOP
	B SVC_ENTRY

SYS_START
	ADR SP, SUP_STACK	; Initialise supervisor stack
	ADD SP, SP, #&40	; Initialise supervisor stack pointer

	LDR R8, =MY_TIMER	; Load address of my timer
	LDR R9, =TIMER		; Load address of hardware timer
	
	MOV R3, #0	    	; Initialise our counter to 0
	STR R3, [R8]	  	; Store back the value

	LDR R10, =PORTA 	; Load port address A

        ; R2 is used to hold the value we should next increment our counter at
	MOV R2, #100		; Set the value we are going to increment timer at to 100

        ; R4 holds the timer "mode" as specified above
	AND R4, R4,  #&0	; Zero out all bits of R4, denoting timer stopped

        ; R5 is used to hold the value in tenths of a second that we should count a new second at
        MOV R5, #&A             ; Set the second counter to 10 (10 * 100ms = 1s)
        
        MOV LR, #&D0            ; Set status flags for user mode
        MSR SPSR, LR            ; Move status to SPSR
        ADR LR, USR_START       ; Set LR to start of user code
        MOVS PC, LR             ; Enter user code

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

USR_START
        SVC 2                   ; Check if it has been a second
        
        B USR_START

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Reads timer, checks if a second has passed by checking if the read
; time (R7) is equal to one second since the previous read (R5)
CHECK_SECOND_HAND
        SVC 0
        LDR R7, [R8]
        CMP R7, R5
        BLGT UPDATE_SECOND_HAND
        B SVC_RETURN
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Rewrites screen, calculates new digits to print, prints them
UPDATE_SECOND_HAND
        SVC 3                   ; Clear screen

        PUSH {R0}               ; Save R0
        MOV R0, R12             ; Set R12 to be the number that gets divided
        PUSH {R12}              ; Save R12 used in division (I know, not ideal)
        SVC 1                   ; Print digits
        POP {R12}               ; Restore R12
        POP {R0}                ; Restore R0

        ADD R12, R12, #&1       ; Incremement seconds counted
        ADD R5, R5, #&A         ; Set next value to increment at as current +10
        POP {LR}                ; Restore call point
        MOV PC, LR              ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Clears the LCD screen
CLEAR_SCREEN
        PUSH {R2}               ; Save R2

        LDRB R2, [R10, #4]      ; Load the value of Port B
        AND R2, R2, #&0         ; Set Read/Write (and eveything else) low
        STRB R2, [R10, #4]      ; Store back to Port B
        
        MOV R2, #&1             ; Set all bits low except bit 0
        STRB R2, [R10]          ; Store to Port A
        
        STRB R2, [R10, #4]      ; Enable bus

        AND R2, R2, #&FE        ; Disable bus

        POP {R2}                ; Restore R2
        
        B SVC_RETURN            ; Return
        
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Entry point for SVC 1 - reads the timer and handles the 100ms counter
; in memory
READ_TIMER
        BL READ_BUTTONS         ; Check status of buttons
CONTINUE
        ; Checking if the timer is in reset mode (R4 bit 1 high)
        PUSH {R4}               ; Push the counter state to the stack
        AND R4, R4, #&2         ; Isolate bit 1 of the state
        CMP R4, #&2             ; If bit 1 is high (denoting reset mode)...
        POP {R4}                ; Retrieve timer state
        BEQ QUERY_RESET         ; ... then check the reset timer
        
        ; Checking if the timer is in run mode (R4 bit 0 high)
        PUSH {R4}               ; Push the counter state to the stack
        AND R4, R4, #&1         ; Isolate bit 0 of the state
        CMP R4, #&1             ; If bit 0 is low (denoting timer not in run mode)...
        POP {R4}                ; Store the timer state back in R4 for checking reset bit
        BNE SVC_RETURN          ; ... then nothing to be done, return
        
        ; If the PC reaches here, it means the timer is running, so we may need to increment
        LDR R1, [R9]            ; Store the value in the hardware timer to R1
        CMP R1, R2              ; Compare the value read from the timer with target value
        BEQ INCREMENT_COUNTER   ; If they are equal, we increment the counter
        B SVC_RETURN            ; Exit and return
        
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Checks if either button is pressed, considering the mode the counter is in

; The order of checks here is important, the first button which is checked
; has precedence on what operation occurs, since each branch does not return
; to this routine, but instead returns to where `READ_BUTTONS` was called. 

; Since resets can only occur if the timer is paused (since they are on the 
; same button), if the start button is pressed then I assume the user does
; not want to stop the timer. Therefore, the start button is checked first and
; given precedence.

READ_BUTTONS
        ; Reading from and formatting port
        LDRB R1, [R10, #4]      ; Load the value at Port B
        AND R1, R1, #&C0        ; Isolate bits 7 and 6 for lower and upper buttons respectively

        ; Check lower button (timer start)
        PUSH {R1}               ; Push button state to stack for later restoration
        AND R1, R1, #&80        ; Isolate bit 7 to check if the lower button is pressed
        CMP R1, #&80            ; If bit 7 is high...
        POP {R1}                ; Restore the value read from the port
        BEQ START_TIMER         ; ... then start the timer
        
        ; Check upper button AND if counter is in reset state
        PUSH {R4}               ; Push counter state to stack for later restoration
        AND R4, R4, #&2         ; Isolate bit 1 to check if timer is in reset state
        PUSH {R1}               ; Push button state to stack for later restoration
        AND R1, R1, #&40        ; Isolate bit 7 to check if the upper button is pressed
        ORR R1, R1, R4          ; Overlay bits
        CMP R1, #&42            ; If bit 6 AND bit 1 are high...
        POP {R1}                ; Restore the value read from the port
        POP {R4}                ; Restore the balue of the counter state
        BEQ QUERY_RESET         ; ... then the button is being held

        ; Otherwise, either the upper button is not held, or it is the first
        ; cycle which it is being pressed.

        ; Check upper button (timer stop)
        PUSH {R1}               ; Push button state to stack for later restoration
        AND R1, R1, #&40        ; Isolate bit 7 to check if the upper button is pressed
        CMP R1, #&40            ; If bit 6 is high...
        POP {R1}                ; Restore the value read from the port
        BEQ STOP_TIMER          ; ... then stop the timer
        
        ; If none of the branches are taken, it means no buttons are being pressed/held
        AND R4, R4, #&1         ; Set bit 1 of the counter state to 0 denote not in reset mode
        MOV R6, #&0             ; Zero the reset counter
        
        B CONTINUE              ; Return to this timer read

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Check if we should increment the reset counter, which counts how long
; the top button has been held
QUERY_RESET
        LDR R1, [R9]            ; Load the value in hardware clock to R1
        CMP R1, R3              ; If current time is equal to time we update at...
        BEQ UPDATE_RESET        ; ... then update the reset timer
        B CONTINUE              ; Otherwise, continue with read
        
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Updates mode
START_TIMER
        ORR R4, R4, #&1         ; Set bit 0 high to denote running mode
        B CONTINUE              ; Continue the timer read

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Increments the reset counter, and calls the timer reset
UPDATE_RESET
        ADD R6, R6, #&1         ; Add 1 to the reset counter
        MOV R3, R1              ; Update time to update to current time...
        ADD R3, R3, #&64        ; ... plus 100 (ms) such that it updates every 100ms
        CMP R3, #&FF            ; May go over 255 so need to normalise...
        BLGT MODULO_R
        CMP R6, #&A             ; 10 updates @ 1 update/100ms  = 1 second
        BGT RESET_TIMER         ; If we have held for 1 second then RESET
        B READ_TIMER            ; Otherwise, continue with read

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Stops the timer and updates modes
STOP_TIMER
        LDRB R3, [R9]           ; Load value from hardware to track when we should update reset timer
        AND R4, R4, #&2         ; Set bit 0 low to denote pause (not running) mode
        ORR R4, R4, #&2         ; Set bit 1 high to denote reset mode (since may be being held)
        B READ_TIMER            ; Go to new read

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Zeroes out my timer and updates modes. Resets LCD and prints 0
RESET_TIMER
        SVC 3                   ; Clear the screen
        MOV R6, #&0             ; Set the reset counter to 0

        STRB R6, [R8]           ; Set the timer to 0 

        SVC 1                   ; Print our 0
        
        MOV R5, #&A             ; Set our second update-at to 10 (10 * 100ms = 1 second)
        MOV R12, #&0            ; Reset our second hand

        AND R4, R4, #&1         ; Set bit 1 of R4 low to denote we are not resetting
        B READ_TIMER            ; Go to new read

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Routine which increments the memory timer
INCREMENT_COUNTER
	ADD R2, R2, #&64        ; Increase value we are next going to increment counter at 
	CMP R2, #255		; If the value is greater than 255...
	BLGT MODULO             ; ... then normalise it

	LDR R1, [R8]		; Increment the counter
	ADD R1, R1, #1
	STR R1, [R8]

	B SVC_RETURN            ; Exit from timer read

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; These 'modulo' functions always works as at any time that this routine is called,
; R2 is at most 100 + 255 (from code above) therefore, subtracting 255 once is
; always sufficient for returning to the 0 - 255 interval
MODULO
	SUB R2, R2, #255	; Subtract 255 from the target value to normalise 
	MOV PC, LR              ; Return

MODULO_R
        SUB R3, R3, #255        ; Subtract 255 from the target value to normalise 
        MOV PC, LR              ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Performs division and prints the digits in decimal format to the LCD
GET_DIGITS
        MOV R12, #0             ; Initialise our digit counter to 0
GET_DIGIT
        ADD R12, R12, #&1       ; We have a digit, increment
        BL DIV_TEN              ; Perform division. R0 <- quotient, R1 <- remainder
        PUSH {R1}               ; Push remainder
        CMP R0, #&0             ; If the result of division is not 0...
        BNE GET_DIGIT           ; ... then divide again
        
PRINT_DIGIT
        CMP R12, #&0            ; If we have no more digits to print...
        BEQ SVC_RETURN          ; Return
        SUB R12, R12, #&1       ; Subtract 1 to denote we have printed a digit
        POP {R0}                ; Put remainder into R0 for printing
        ADD R0, R0, #&30        ; ASCIIfy
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
        LDR R2, =0x1999999A     ; Move reciprocal of 10 to R2
        UMULL R1, R0, R1, R2    ; Multiply R1 by reciprocal, R0 containing LSBs
        
        MOV R1, R0              ; Copy quotient to R1
        MOV R2, #&A             ; Load 10 for later multiplication
        MUL R1, R1, R2          ; Quotient * 10 = R0 `div` 10
        
        POP {R2}                ; Put original dividend (R0) to R2
        SUB R1, R2, R1          ; dividend - (dividend `div` 10) = (dividend `mod` 10) i.e. remainder
        POP {R2}                ; Restore the orginal value back to R2

        POP {LR}                ; Restore return location
        MOV PC, LR              ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Prints the ASCII character whose code is the value stored in R0
PRINT_CHAR
        PUSH {LR}               ; Save call point
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

; Enable the LCD backlight
ENABLE_LCD
	LDRB R2, [R10, #4]      ; Load value of Port B
	ORR R2, R2, #&20        ; Set bit 5 high to enable LCD
	STRB R2, [R10, #4]      ; Store back to Port B
        MOV PC, LR              ; Return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Check if LCD is accesible
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

; Calculates the SVC number to jump to by referencing the instruction which called it
SVC_ENTRY
	PUSH {LR}               ; Push instruction AFTER SVC call onto stack
	LDR LR, [LR, #-4]       ; Load instruction BEFORE that pointed by LR, i.e. SVC instruction
	BIC LR, LR, #&FF000000  ; Clear 8 MSBs, leaving 24 bit number passed to SVC

	CMP LR, #&3             ; If SVC number is out of range...
	BHI .                   ; ... then end...
	ADR R11, JUMP_TABLE     ; ... else then store jump table address in R11...
        LDR PC, [R11, LR, LSL #2]       ; LR LSL 2 = LR * 2 => For SVC x we have JUMP_TABLE + 4x

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Returns to callpoint and resets flags
SVC_RETURN
        POP {LR}                ; Restore call point
        MOVS PC, LR             ; Return and set flags

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

JUMP_TABLE
	DEFW READ_TIMER         ; SVC 0
        DEFW GET_DIGITS         ; SVC 1
        DEFW CHECK_SECOND_HAND  ; SVC 2
        DEFW CLEAR_SCREEN       ; SVC 3


ALIGN
SUP_STACK DEFS 128
