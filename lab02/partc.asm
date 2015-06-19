; Part C - Min/Max
; Max: XH:XL
; Min: YH:YL
; If no nodes are created, returns X = 0 and Y = 32,768.
.include "m2560def.inc"

.def temp = r16

.def IL = r18
.def IH = r19

.set NEXT_INT = 0x0000
.macro defint ; signed 16-bit (2 bytes/1 word) integer
    .set T = PC             ; save current position in program memory
    .dw NEXT_INT << 1    	; write out address of next list node
    .set NEXT_INT = T    	; update NEXT_INT to point to this node

	.dw @0					; store int
.endmacro

.cseg
    rjmp start
    defint 0x64
	defint -1 	; 0xFFFF
	defint 0x01
	defint -20	; min 0xFFEC
	defint 0x02
	defint 2000 ; max 0x7D0

start:
    ldi temp, low(RAMEND)        	; initialise stack pointer
    out SPL, temp
    ldi temp, high(RAMEND)
    out SPH, temp
    
    ldi ZL, low(NEXT_INT << 1)   	; initialise Z pointer to byte address of first entry
    ldi ZH, high(NEXT_INT << 1)
    
    rcall search                	; call search function

halt:
	rjmp halt

search:
	cpi ZL, 0						; check if NEXT_INT = null
	ldi temp, 0
	cpc ZH, temp
	brne notnull
	ldi XL, 0						; set X = 0
	ldi XH, 0
	ldi YL, 0xFF					; set Y = 32,768 (highest number)
	ldi YH, 0x00
	rjmp return

	notnull:
	lpm YL, Z+						; find address from this struct -> Y
	lpm YH, Z

	cpi YL, 0						; compare to 0x00
	ldi temp, 0
	cpc YH, temp

	breq endnode					; if Y == 0 go to endnode
	; else, when Y != 0
		push ZH						; push Z
		push ZL
		movw ZL, YL					; Y -> Z
		
		rcall search				; at this point, Y -> min, X -> max from other nodes
	
		pop ZL						; pop Z
		pop ZH
		
		ldi temp, 1					; increase Z to reach int inside data structure
		add ZL, temp
		ldi temp, 0
		adc ZH, temp

		lpm IL, Z+					; take int from struct -> I
		lpm IH, Z
		
		; compare I with Y and X from search function calls to other nodes
		; min -> Y
			; if I > Y, return Y
			cp IL, YL
			cpc IH, YH
			brge max
			; if I < Y, return I
			movw YL, IL
		max: ; -> X
			; if I < X, return X
			cp IL, XL
			cpc IH, XH
			brlt return
			; if I > X, return I
			movw XL, IL
		
		rjmp return

	endnode:
		subi ZL, 1					; restore Z to original address
		sbci ZH, 0

		ldi temp, 2					; increase Z to reach int
		add ZL, temp
		ldi temp, 0
		adc ZH, temp

		lpm IL, Z+					; take int from struct -> I
		lpm IH, Z
		
		; compare I with Y = 00FF and X = 0
		ldi XL, 0						; initialise max to 0
		ldi XH, 0

		ldi YL, 0xFF					; initialise min to 32,768 (highest signed number)
		ldi YH, 0x00

		; min -> Y
			; if I > Y, return Y
			cp IL, YL
			cpc IH, YH
			brge max2
			; if I < Y, return I
			movw YL, IL
		max2: ; -> X
			; if I < X, return X
			cp IL, XL
			cpc IH, XH
			brlt return
			; if I > X, return I
			movw XL, IL

	return:
	ret
