; COMP22712 - Exercise 3 - Nesting Procedure Calls
; Cyrus Knopf - f10983ck - 07/02/2024

; As per ARM Procedure Call Standards:
; https://github.com/ARM-software/abi-aa/releases/download/2023Q3/aapcs32.pdf 
; Registers R7, R8 are used for variables,
; namely the addresses of Port A and B
; repsectively. R0 is used to pass the 
; string/character parameter to the
; subroutine.

; load header files specifying port addresses
INCLUDE headers.s
		; Load addresses of Port B to R7, 
		; Load Port A to R8
		LDR R8, =PORTA
		LDR R7, =PORTB

		; entry point
		; init stack
		ADR SP, STACK
		; increment to bottom of stack
		ADD SP, SP, #&40

		; load a char to R0
		ADR R0, MYCHAR1
		; call write char directive
		BL WRITECHAR
        BL CLEARSCREEN

		B END



CLEARSCREEN
        LDRB R2, [R7]
        AND R2, R2, #&0
        STRB R2, [R7]

        LDRB R2, [R8]
        AND R2, R2, #&0
        ORR R2, R2, #&1
        STRB R2, [R8]

		ORR R2, R2, #&1
		STRB R2, [R7]
		;Disable Bus
		AND R2, R2, #&FE
		STRB R2, [R7]

        MOV PC, LR


WRITECHAR
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

END
		B END
	


MYCHAR1 DEFB 'l'
MYCHAR2 DEFB 's'

STACK DEFS 128
