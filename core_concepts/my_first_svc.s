INCLUDE headers.s

	B SYS_START
	NOP ; Reserved for undefined instruction exception
	; Use Branch not Branch Link so we don't overwrite the LR
	; (We never need to return to this location)
	B SVC_ENTRY



SYS_START
	; In supervisor mode...
	; Initialise supervisor stack
	ADR SP, SUP_STACK
	; Initialise supervisor stack pointer
	ADD SP, SP, #&40
	
	; Switch to User mode:
	; Correct status, flags etc. into LR
	MOV LR, #&D0
	; Load that status into SPSR
	MSR SPSR, LR
	; Set LR to start of user code
	ADR LR, USR_START
	; PC to user code
	MOVS PC, LR
	

USR_START
	; Initialise user stack
	ADR SP, USR_STACK
	; Increment stack pointer to bottom of stack
	ADD SP, SP, #&40



	; load the word to write to R0
	ADR R0, MYWORD1
	; call write word supervisor call
	SVC 0

	; load a char to R0
	ADR R0, MYCHAR1
	; call write char directive
	BL WRITECHAR

	; repeat for another char
	ADR R0, MYCHAR2
	BL WRITECHAR

	; repeat for another word
	ADR R0, MYWORD2
	BL WRITEWORD

	B END


WRITEWORD
	; push call point to stack
;	STMFD SP!, {LR}
CONTINUE
	; write the first character
	BL WRITECHAR
	; after returning from WRITECHAR
	; directive, incrememnt one byte
	; to get next char
	ADD R0, R0, #&1
	; load current char to R3 to check
	; if it is stop char
	LDRB R3, [R0]
	CMP R3, #&00
	; if its not the stop char, branch
	; back to write next char, otherwise
	; return
	BNE CONTINUE
	LDMFD SP!, {LR}
	MOV PC, LR

WRITECHAR
	; Load addresses of Port B to R7, 
	; Load Port A to R8
	LDR R8, =PORTA
	LDR R7, =PORTB

	; turn on LED backlight
	LDRB R2, [R7]
	ORR R2, R2, #&20
	STRB R2, [R7]



CHECKLCDIDLE
	; Set read
	LDRB R2, [R7]
	ORR R2, R2, #&4
	STRB R2, [R7]

	; Set control
	AND R2, R2, #&FD
	STRB R2, [R8]

	; Set enable bus
	ORR R2, R2, #&1
	STRB R2, [R7]

	; Read LCD status byte from Port A
	LDRB R3, [R8]

	; Read Port B 
	LDRB R2, [R7]
	; Disable bus
	AND R2, R2, #&FE
	STRB R2, [R7]
	
	; Zero out bits 1-6
	AND R3, R3, #&80

	; Check if 7th bit high
	CMP R3, #&80
	;  with data bus If high, branch back
	BEQ CHECKLCDIDLE

	; Set write
	AND R2, R2, #&FB
	STRB R2, [R7]

	; Set bus output
	ORR R2, R2, #&2
	STRB R2, [R7]

	; Output byte (ascii char) on data bus
	LDR R4, [R0]
	STRB R4, [R8]

	; Enable bus
	ORR R2, R2, #&1
	STRB R2, [R7]
	;Disable Bus
	AND R2, R2, #&FE
	STRB R2, [R7]


	; return to caller
	MOV PC, LR

SVC_ENTRY
	; TODO: Change to bounds of jump table
	; Pushes instruction after the SVC call onto the stack
	PUSH {LR}
	; Load the instruction BEFORE the instruction saved,
	; i.e. the SVC instruction ITSELF
	LDR LR, [LR, #-4]
	; Clear out the top 8 bit, leaving the 24 bit number passed to SVC
	BIC LR, LR, #&FF000000

	CMP LR, #&2
	; if the SVC value is higher than the max, end
	BHI .
	ADR R10, JUMP_TABLE
	LDR PC, [R10, LR, LSL #2]


JUMP_TABLE
	DEFW WRITEWORD
	DEFW WRITECHAR


END
	B END
	



MYWORD1 DEFB "cd 2; \0"
MYWORD2 DEFB "; tmux\0"
MYCHAR1 DEFB 'l'
MYCHAR2 DEFB 's'

; Align stacks on word line
ALIGN
SUP_STACK DEFS 128
USR_STACK DEFS 128
