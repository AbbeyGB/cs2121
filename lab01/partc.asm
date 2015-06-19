.include "m64def.inc"
; Part C
	rjmp start				; jump over data definitions
.equ endofstring=0
.equ conversion=32
.def char=r16

str:
	.cseg
	.db "lowercaseword!!!!!?",0	; should be even

start:
	ldi r31, high(str<<1)	; z-pointer to string in cseg
	ldi r30, low(str<<1)

	ldi r29, high(0x200)	; y-pointer to beginning of SRAM
	ldi r28, low(0x200)

copy:
	lpm char, z+			; load data from string
	st y+, char				; store into SRAM
	cpi char, endofstring	; check char=0
	brne copy				; if not, jump back

	ldi r29, high(0x200)	; y-pointer to beginning of SRAM
	ldi r28, low(0x200)

convert:					; convert to uppercase (-32=2^5) if lowercase (97-122)
	ld char, y				; load char from SRAM
	cpi char, endofstring	; check char=0
	breq halt				; if true, jump back
	cpi char, 97			; check if char >= 97
	brlo skipcon			; skip conversion if not lowercase
	ldi r18, 123
	cp r18, char			; check if char <123
	brlo skipcon			; skip conversion if not lowercase
	subi char, conversion	; convert to uppercase
skipcon:
	st y+, char
	rjmp convert

halt:
	rjmp halt
