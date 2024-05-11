include headers.s

	B SYS_START             ; Reset
	NOP                     ; Undefined instruction
	B SVC_ENTRY             ; SVC calls
        NOP                     ; Prefetch abort
        NOP                     ; Data abort
        NOP                     ; - - - 
        B SERVICE_IRQ           ; Interrupt service
        B SERVICE_FIQ           ; Fast interrupt service

SYS_START
	ADR SP, SUP_STACK	; Initialise supervisor stack
	ADD SP, SP, #&40	; Initialise supervisor stack pointer
        
        MOV LR, #&D2            ; Set flags for IRQ mode (with interrupts disabled (bits 7,6 high))
        MSR CPSR, LR            ; Enter IRQ mode        
        ADR SP, ITR_STACK       ; Initialise interrupt stack
        ADD SP, SP, #40         ; Initialise interrupt stack pointer

        LDR R3, =ITRPT_EN       ; Load port to enable device interrupts
        MOV R4, #&C0            ; Only enable buttons to interrupt TODO Change desired devices
        STRB R4, [R3]           ; Store to port

        MOV LR, #&10            ; Set status flags for user mode (with interrupts enabled)
        MSR SPSR, LR            ; Move status to SPSR
        ADR LR, USR_START       ; Set LR to start of user code
        MOVS PC, LR             ; Enter user code

USR_START
        B .                     ; TODO Implement user program here

SERVICE_IRQ
        SUB LR, LR, #4          ; Correct return address
        PUSH {LR}               ; Save return address

        ; TODO Acknowledge interrupting device, and call desired method

        POP {PC}^               ; Restore registers and return

SERVICE_FIQ
        SUB LR, LR, #4          ; Correct return address
        PUSH {LR}               ; Save return address

        POP {PC}^               ; Restore registers and return

; Calculates the SVC number to jump to by referencing the instruction which called it
SVC_ENTRY
	PUSH {LR}               ; Push instruction AFTER SVC call onto stack
	LDR LR, [LR, #-4]       ; Load instruction BEFORE that pointed by LR, i.e. SVC instruction
	BIC LR, LR, #&FF000000  ; Clear 8 MSBs, leaving 24 bit number passed to SVC

	CMP LR, #&3             ; TODO Specify max SVC - If SVC number is out of range...
	BHI .                   ; ... then end...
	ADR R11, JUMP_TABLE     ; ... else then store jump table address in R11...
        LDR PC, [R11, LR, LSL #2]       ; LR LSL 2 = LR * 2 => For SVC x we have JUMP_TABLE + 4x

JUMP_TABLE
        ;SVC 1
        ;SVC 2
        ;SVC 3
        ; ... 


ALIGN                           ; Ensures stacks are word aligned
SUP_STACK DEFS 128              ; Stack for supervisor mode
ITR_STACK DEFS 128              ; Stack for interrupt requests
