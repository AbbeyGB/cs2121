.include "m64def.inc"

; Part B

.dseg
.org 0x200

array:	.byte 5

.cseg
	rjmp start
start:
	ldi r16, 1
	ldi r17, 2
	ldi r18, 3
	ldi r19, 4
	ldi r20, 5	

	ldi r21, 5
	ldi r22, 4
	ldi r23, 3
	ldi r24, 2
	ldi r25, 1

addarr:
	add r16, r21
	add r17, r22
	add r18, r23
	add r19, r24
	add r20, r25

store:
	ldi r26, low(array)
	ldi r27, high(array)
	st X+, r16
	st X+, r17
	st X+, r18
	st X+, r19
	st X+, r20

halt:
	rjmp halt
