.include "m64def.inc"
.equ val1 = 640
.equ val2 = 511
; Part A

	ldi r17, high(val1)		; r17:r16=val1
	ldi r16, low(val1)
	ldi r19, high(val2)		; r19:r18=val2
	ldi r18, low(val2)
	
	add r16, r18			; add low bytes
	adc r17, r19			; add high bytes and carry
	
	mov r20, r16
	mov r21, r17			; Result should be 43690 (0xAAAA) for case 1

halt:
	rjmp halt
