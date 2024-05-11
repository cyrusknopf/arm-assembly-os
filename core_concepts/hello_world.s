	; entry point
	MOV R9, #&42

	BL WRITECHAR
	MOV R9, #&43

	BL WRITECHAR
	MOV R9, #&44
WRITECHAR
	; Load addresses of Port B to R0, 
	; Load Port A to R1
	MOV R0, #&10000004
	MOV R1, #&10000000


	LDRB R2, [R0]
	ORR R2, R2, #&20
	STRB R2, [R0]

	; Zero out R2
	;AND R2, R2, #&0

	; Zero out both ports
	;STRB R2, [R0]
	;STRB R2, [R1]

	LDRB R2, [R0]
CHECKLCDIDLE
	; Set read
	ORR R2, R2, #&4
	STRB R2, [R0]

	; Set control
	AND R2, R2, #&FD
	STRB R2, [R0]

	; Set enable bus
	ORR R2, R2, #&1
	STRB R2, [R0]

	; Read LCD status byte from Port A
	LDRB R3, [R1]

	; Read Port B 
	LDRB R2, [R0]
	; Disable bus
	AND R2, R2, #&FE
	STRB R2, [R0]
	
	; Zero out bits 1-6
	AND R3, R3, #&80
	
	; Check if 7th bit high
	CMP R3, #&80
	;  with data bus dIf high, branch back
	BEQ CHECKLCDIDLE

	; Set write
	AND R2, R2, #&FB
	STRB R2, [R0]

	; Set bus output
	ORR R2, R2, #&2
	STRB R2, [R0]

	; Output byte (ascii char) on data bus
	MOV R4, R9
	STRB R4, [R1]

	; Enable bus
	ORR R2, R2, #&1
	STRB R2, [R0]
	;Disable Bus
	AND R2, R2, #&FE
	STRB R2, [R0]


	; return to caller
	MOV PC, LR



Micro DEFB "Micro"
