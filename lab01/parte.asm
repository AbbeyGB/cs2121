.include "m64def.inc"
; Part E
.equ endofstring = 0
.def strval = r16
.def counter = r17
.def left = r18
.def right = r19
.def temp = r20

; should use the following:
.dseg
.org 0x200
.cseg
array: 	.db 7
		.db 4
		.db 5
		.db 1
		.db 6
		.db 3
		.db 2

.macro	ldv
	ldi strval, @0			; value to load into array
	st y+, strval
.endmacro	

load:
	ldi r28, low(0x200)		; y = 0x200
	ldi r29, high(0x200)

	ldv 7
	ldv 4
	ldv 5
	ldv 1
	ldv 6
	ldv 3
	ldv 2

	ldi r28, low(0x200)		; y = 0x200
	ldi r29, high(0x200)
	ldi counter, 6			; counter = 6
	ldi r16, 0				; r16 (index) = 0

sort:
	ld left, y+				; load y+1 into left
	ld right, y				; load y into right
	cp right, left			; (y) - (y+1)
	brlo switch				; if (y) < (y+1) then switch

sort2:
	inc r16					; r16 (index) ++
	cp r16, counter			; if r16 (index) < counter (string length)
	brlo sort				; go to sort

	dec counter				; reduce string length because last element is sorted
	cpi counter, 0			; if counter == 0
	breq halt				; go to halt
	ldi r16, 0				; reset index to 0
	ldi r28, low(0x200)		; y = 0x200
	ldi r29, high(0x200)
	rjmp sort				; go to sort
	
switch:
	mov temp, right			; temp = r
	st y, left				; r = l
	st -y, temp				; l = temp
	adiw r28, 1
	rjmp sort2

halt:
	rjmp halt
