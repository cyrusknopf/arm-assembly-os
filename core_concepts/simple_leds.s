; Initial Setup: turn off all lights and write LED
; address to R0
MOV R0, #&10000000
LDRB R1, [R0]
AND R1, R1, #&0
STRB R1, [R0]

; Turn on both red lights
ORR R1, R1, #&44
STRB R1, [R0]

; Turn on left orange light
ORR R1, R1, #&2
STRB R1, [R0]

; Turn off left lights
AND R1, R1, #&F0

; Turn on left green
ORR R1, R1, #&1
STRB R1, [R0]

; Turn off left lights, turn on left amber
AND R1, R1, #&F0
ORR R1, R1, #&2
STRB R1, [R0]

; Turn off left lights, turn on left red
AND R1, R1, #&F0
ORR R1, R1, #&4
STRB R1, [R0]

; Turn on right amber
ORR R1, R1, #&20
STRB R1, [R0]

; Turn off right red & amber, turn on right green
AND R1, R1, #&9F
ORR R1, R1, #&10
STRB R1, [R0]

; Turn off right green
AND R1, R1, #&EF
STRB R1, [R0]

; Turn on right amber
ORR R1, R1, #&20
STRB R1, [R0]

; Restart
MOV PC, #&0
