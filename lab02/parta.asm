; Part A - Reverse String
.include "m2560def.inc"

.def char = r16
.def length = r17

.cseg
	rjmp start
str: .db "abc", 0

start:
	; initialise pointer to input string in program memory
	ldi ZL, low(str<<1)
	ldi ZH, high(str<<1)
	; initialise stack pointer
	ldi r18, low(RAMEND)
	out SPL, r18
	ldi r18, high(RAMEND)
	out SPH, r18
	; initialise pointer to output string in data memory
	ldi YL, low(0x200)
	ldi YH, high(0x200)
	; initialise length to 0
	ldi length, 0

	; load string into stack from program memory
load:
	; load char from program memory
	lpm char, Z+
	; branch to store if null reached
	; this should stay here so that you don't push 0 onto the stack
	cpi char, 0
	breq store
	; push onto stack
	push char
	inc length
	rjmp load
	
	; write reversed string to data memory
store:
	; pop char off stack
	pop char
	dec length
	; write char to data memory, increment Y
	st Y+, char
	; branch to end if reached end of string
	cpi length, 0
	breq end
	rjmp store

end:
	ldi char, 0
	st Y+, char

halt:
	rjmp halt
