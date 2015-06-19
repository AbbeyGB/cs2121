; Part B - Recursive Linked-list search
; Should return length of string in r16

.include "m2560def.inc"

.def length = r16
.def templength = r17
.def char = r18
.def temp = r18

.set NEXT_STRING = 0x0000
.macro defstring ; str
	.set T = PC				; save current position in program memory
	.dw NEXT_STRING	<< 1	; write out address of next list node
	.set NEXT_STRING = T	; update NEXT_STRING to point to this node

	.if strlen(@0) & 1		; odd length + null byte
		.db @0, 0
	.else					; even length + null byte, add padding byte
		.db @0, 0, 0
	.endif
.endmacro

.cseg
	rjmp start
	defstring "a really long string"	;length 20 0x14
	defstring "macros"			; length 6 0x06
	defstring "are"				; length 3 0x03
	defstring "very stupid"		; length 11 0x0B
	defstring "testing"			; length 4 0x04
	defstring "a really long string"	;length 20 0x14

start:
	ldi temp, low(RAMEND)		; initialise stack pointer
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	
	ldi ZL, low(NEXT_STRING << 1)	; initialise Z pointer to byte address of first entry
	ldi ZH, high(NEXT_STRING << 1)
	
	ldi length, 0					; initialise length
	
	rcall search				; call search function

halt:
	rjmp halt

search:
	push ZH
	push ZL
	push YH
	push YL
	push XH
	push XL
	push temp
	push templength
	push char
	
	cpi ZL, 0					; check if input is null
	ldi temp, 0
	cpc ZH, temp
	brne notnull
	rjmp return					; if input is null, return Z = null and r16 = 0

	notnull:
	push ZH						; store old address Z -> stack
	push ZL

	lpm YL, Z+					; get next address from struct by temporarily using Y
	lpm YH, Z
	
	subi ZL, 1					; reset Z to original value
	ldi temp, 0
	sbc ZH, temp

	cpi YL, 0					; if Y == 0x0000 then jump to skipcall
	ldi temp, 0
	cpc YH, temp
	breq skipcall
		movw ZL, YL					; put next address in Z
		push temp
		rcall search				; since Z != 0x0000 call search
		pop temp
		movw YL, ZL					; store new value of Z into Y
		in XL, SPL					; retrieve old values of Z from stack
		in XH, SPH
	    ldi temp, 1
        add XL, temp
        ldi temp, 0
        adc XH, temp
        ld ZL, X+
        ld ZH, X

	skipcall:

	ldi templength, 0			; find length of the string
	ldi temp, 2							; make sure Z is at beginning of string
	add ZL, temp						; instead of at the address
	ldi temp, 0
	adc ZH, temp
	loop:
		lpm char, Z+					; load char
		cpi char, 0						; check if null
		breq compare					; if null jump to compare
		inc templength					; if not, increment
		rjmp loop

	compare:					; compare length to templength, use skip instr
		cp length, templength
		brsh other						; if templength > length, length = templength and Z = stack value
			mov length, templength
			pop ZL
			pop ZH
			rjmp return
		other:							; else if templength <= length, Z = Y and length = length
			movw ZL, YL					; i.e. if length >= templength
			pop temp
			pop temp
	return:
	pop char
	pop templength
	pop temp
	pop XL
	pop XH
	pop YL
	pop YH
	pop ZL
	pop ZH
	ret
