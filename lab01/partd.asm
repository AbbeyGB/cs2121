.include "m64def.inc"
; Part D
	rjmp start							; jump over data definitions
.equ endofstring	=	0
.def index			=	r16
.def char			=	r17
.equ findchar		=	'b'				; character to search for

str:
	.cseg
	.db "abcdefghijklmnopqrstuvwxyz!",0	; should be even

start:
	ldi r30, low(str)							; z = 0
	ldi r31, high(str)
	clr index							; index = 0

search:
	lpm char, z+						; load next char from string
	cpi char, findchar					; if char found go to halt
	breq halt
	cpi char, endofstring				; if null go to notfound
	breq notfound
	inc index							; index++
	rjmp search							; go back to search

notfound:
	ldi index, 0xff						; store 0xff

halt:
	rjmp halt
