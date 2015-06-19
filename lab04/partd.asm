; Part D: Multiplication and Subtraction
; Implement 8-bit multiplication and division.

.include "m2560def.inc"

; Delay Constants
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4 				; 4 cycles per iteration - setup/call-return overhead

; LCD Instructions
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.set LCD_DISP_ON = 0b00001110
.set LCD_DISP_OFF = 0b00001000
.set LCD_DISP_CLR = 0b00000001

.set LCD_FUNC_SET = 0b00111000 						; 2 lines, 5 by 7 characters
.set LCD_ENTR_SET = 0b00000110 						; increment, no display shift

.set LCD_HOME_LINE = 0b10000000 					; goes to 1st line (address 0)
.set LCD_SEC_LINE = 0b10101000 						; goes to 2nd line (address 40)

; LCD Macros
.macro do_lcd_command
	ldi param, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_command_reg
	mov param, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi param, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_reg
	mov param, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

; Keypad
.def row = r17										; current row number
.def col = r18										; current column number
.def rmask = r19									; mask for current row during scan
.def cmask = r20									; mask for current column during scan

.equ PORTLDIR = 0xF0								; -> 1111 0000 PL7-4: output, PL3-0, input
.equ INITCOLMASK = 0xEF								; -> 1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01								; -> 0000 0001 scan from the top row
.equ ROWMASK  = 0x0F								; -> 0000 1111 for obtaining input from Port L (note that first 4 bits are output)

; Calculator
.def currentL = r2
.def currentH = r3
.def accumulatorL = r4
.def accumulatorH = r5
.def address = r6
.def addressc = r7

; General
.def param = r16
.def temp1 = r21
.def temp2 = r22

.macro jeq
   brne pc+2
   rjmp @0
.endm

.macro jne
   breq pc+2
   rjmp @0
.endm

.macro jlo
   brsh pc+2
   rjmp @0
.endm

.macro jsh
   brlo pc+2
   rjmp @0
.endm

.dseg
	digits: .byte 4
	currPress: .byte 1
	wasPress: .byte 1
	divideResult: .byte 1
	divideRem: .byte 1
	multiplyCounter: .byte 1
	multiplyOperand: .byte 1
	isPrinted: .byte 1
	digit5: .byte 1
	digit4: .byte 1
	digit3: .byte 1
	digit2: .byte 1
	digit: .byte 1

.cseg
; Vector Table
.org 0
	jmp RESET


RESET:
	ldi param, low(RAMEND)
	out SPL, param
	ldi param, high(RAMEND)
	out SPH, param

	ser param 										; set PORTF and PORTA to output
	out DDRF, param
	out DDRA, param
	clr param										; clear PORTF and PORTA registers
	out PORTF, param
	out PORTA, param

	ldi temp1, PORTLDIR								; set PL7:4 to output and PL3:0 to input
	sts DDRL, temp1

	do_lcd_command LCD_FUNC_SET 					; initialise LCD
	rcall sleep_5ms
	do_lcd_command LCD_FUNC_SET
	rcall sleep_1ms
	do_lcd_command LCD_FUNC_SET
	do_lcd_command LCD_FUNC_SET
	do_lcd_command LCD_DISP_OFF
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_ENTR_SET
	do_lcd_command LCD_DISP_ON

	do_lcd_data '0'									; initialise variables
	clr accumulatorL
	clr currentL
	ldi temp1, LCD_HOME_LINE
	mov address, temp1
	ldi temp1, LCD_SEC_LINE
	mov addressc, temp1
	clr temp1
	sts digits, temp1
	sts digits + 1, temp1
	sts digits + 2, temp1
	sts digits + 3, temp1
	sts currPress, temp1
	sts wasPress, temp1

	do_lcd_command LCD_SEC_LINE

main:
	ldi cmask, INITCOLMASK							; initial column mask (1110 1111)
	clr col 										; initial column (0)
	jmp colloop

keysScanned:
	ldi temp1, 0 									; set currPress = 0
	sts currPress, temp1
	jmp main

colloop:
	cpi col, 4 										; compare current column # to total # columns
	breq keysScanned								; if all keys are scanned, repeat
	sts PORTL, cmask								; otherwise, scan a column

	ldi temp1, 0xFF									; slow down the scan operation to debounce button press
	delay:
	dec temp1
	brne delay
	rcall sleep_20ms

	lds temp1, currPress 							; if currPress = 0, set wasPress = 0
	cpi temp1, 1
	brne notPressed
	ldi temp1, 1									; set wasPress = 1
	sts wasPress, temp1
	jmp scan
	notPressed:
		ldi temp1, 0 								; set wasPress = 0
		rcall sleep_5ms
		sts wasPress, temp1

	scan:
	lds temp1, PINL									; read PORTL
	andi temp1, ROWMASK								; get the keypad output value
	cpi temp1, 0xF0 								; check if any row is low (0)
	breq rowloop									; if yes, find which row is low
	ldi rmask, INITROWMASK							; initialize rmask with 0000 0001 for row check
	clr row

rowloop:
	cpi row, 4 										; compare current value of row with total number of rows (4)
	breq nextcol									; if theyre equal, the row scan is over.
	mov temp2, temp1 								; temp1 is 0xF
	and temp2, rmask 								; check un-masked bit
	breq convert 									; if bit is clear, the key is pressed
	inc row 										; else move to the next row
	lsl rmask 										; shift row mask left by one
	jmp rowloop

nextcol:											; if row scan is over
	lsl cmask 										; shift column mask left by one
	inc col 										; increase column value
	jmp colloop										; go to the next column

convert:
	ldi temp1, 1 									; set currPress = 1
	sts currPress, temp1
	lds temp1, wasPress 							; if wasPress = 1, ignore keypad press
	cpi temp1, 1
	breq main

	cpi col, 3										; if the pressed key is in col.3 
	breq letters									; we have a letter
	cpi row, 3										; if the key is not in col 3 and is in row3,
	breq symbols									; we have a symbol or 0
	mov temp1, row 									; otherwise we have a number in 1-9
	lsl temp1 										; multiply temp1 by 2
	add temp1, row 									; add row again to temp1 -> temp1 = row * 3
	add temp1, col 									; temp1 = col*3 + row
	inc temp1

number:
	ldi temp2, 10 									; multiply by 10
	mul currentL, temp2
	movw currentH:currentL, r1:r0
	add currentL, temp1 							; add new digit
	ldi temp2, 0
	adc currentH, temp2
	subi temp1, -'0' 								; convert to ASCII
	do_lcd_command_reg addressc
	do_lcd_data_reg temp1
	inc addressc
	jmp main										; restart main loop

letters:
	cpi row, 1
	breq subtraction 								; if row 1, B was pressed
	cpi row, 0
	breq addition 									; if row 0, A was pressed
	cpi row, 2
	breq multiplication
	cpi row, 3
	breq division
	jmp main

addition:
	add accumulatorL, currentL 						; A was pressed, so we need to perform addition
	adc accumulatorH, currentH
	rjmp addsubdiv
subtraction:
	sub accumulatorL, currentL
	sbc accumulatorH, currentH
	rjmp addsubdiv
division:
	rcall divide
addsubdiv:
	clr accumulatorH
	clr currentL
	clr currentH
	ldi temp1, 128
	mov address, temp1
	ldi temp1, 168
	mov addressc, temp1
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_HOME_LINE
	rcall write16
	do_lcd_command LCD_SEC_LINE
	jmp main

symbols:
	cpi col, 0 										; if its in column 0, it's a star
	breq star
	cpi col, 1 										; if its in column 1, it's a zero
	breq zero
	jmp main

multiplication:
	mul accumulatorL, currentL
	movw accumulatorH:accumulatorL, r1:r0
	clr currentL
	ldi temp1, 128
	mov address, temp1
	ldi temp1, 168
	mov addressc, temp1
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_HOME_LINE
	rcall write16
	do_lcd_command LCD_SEC_LINE
	jmp main

zero:
	ldi temp1, 0
	jmp number

star:
	clr accumulatorL 								; reset accumulator
	clr accumulatorH
	clr currentL
	clr currentH
	ldi temp1, 128
	mov address, temp1
	ldi temp1, 168
	mov addressc, temp1
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_HOME_LINE
	do_lcd_data '0'
	do_lcd_command LCD_SEC_LINE
	jmp main

lcd_command:
	out PORTF, param
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, param
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push param
	clr param
	out DDRF, param
	out PORTF, param
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in param, PINF
	lcd_clr LCD_E
	sbrc param, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser param
	out DDRF, param
	pop param
	ret

; Delay functions
sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

sleep_20ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret

write16b:
	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 7
	ldi param, '1'
	sbrs accumulatorH, 7
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 6
	ldi param, '1'
	sbrs accumulatorH, 6
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait
	
	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 5
	ldi param, '1'
	sbrs accumulatorH, 5
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 4
	ldi param, '1'
	sbrs accumulatorH, 4
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 3
	ldi param, '1'
	sbrs accumulatorH, 3
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 2
	ldi param, '1'
	sbrs accumulatorH, 2
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 1
	ldi param, '1'
	sbrs accumulatorH, 1
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorH, 0
	ldi param, '1'
	sbrs accumulatorH, 0
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 7
	ldi param, '1'
	sbrs accumulatorL, 7
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 6
	ldi param, '1'
	sbrs accumulatorL, 6
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait
	
	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 5
	ldi param, '1'
	sbrs accumulatorL, 5
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 4
	ldi param, '1'
	sbrs accumulatorL, 4
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 3
	ldi param, '1'
	sbrs accumulatorL, 3
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 2
	ldi param, '1'
	sbrs accumulatorL, 2
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 1
	ldi param, '1'
	sbrs accumulatorL, 1
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	do_lcd_command_reg address
	inc address
	sbrc accumulatorL, 0
	ldi param, '1'
	sbrs accumulatorL, 0
	ldi param, '0'
	rcall lcd_data
	rcall lcd_wait

	ret

; Writes 16-bit number in accumulatorH:accumulatorL to the LCD in decimal
write16:
	push accumulatorH
	push accumulatorL
	push temp1

	clr temp1
	sts isPrinted, temp1 							; 0 if not printed, 1 if printed
	sts digit5, temp1
	sts digit4, temp1
	sts digit3, temp1
	sts digit2, temp1
	sts digit, temp1

	write10000s:
		mov temp1, accumulatorL
		cpi temp1, low(10000) 						; check that accumulatorH:accumulatorL > 10000
		ldi temp1, high(10000)
		cpc accumulatorH, temp1
		brlo write1000s
	
		loop10000s:
			mov temp1, accumulatorL
			cpi temp1, low(10000) 					; if < 10000, display ten thousands digit
			ldi temp1, high(10000)
			cpc accumulatorH, temp1
			brlo display10000s

			mov temp1, accumulatorL					; decrement parameter by 10000
			subi temp1, low(10000)
			mov accumulatorL, temp1
			mov temp1, accumulatorH
			sbci temp1, high(10000)
			mov accumulatorH, temp1
		   
			lds temp1, digit5 						; increment ten thousands digit counter
			inc temp1
			sts digit5, temp1
		   
			jmp loop10000s
	   
		display10000s:
			lds temp1, digit5 						; only print if ten thousands digit counter > 0
			cpi temp1, 0
			breq write1000s

			lds temp1, isPrinted 					; set isPrinted to 1
			ldi temp1, 1
			sts isPrinted, temp1

			lds temp1, digit5 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1

	write1000s:
		mov temp1, accumulatorL
		cpi temp1, low(1000) 						; check that accumulatorH:accumulatorL > 1000
		ldi temp1, high(1000)
		cpc accumulatorH, temp1
		brlo space1000s
	
		loop1000s:
			mov temp1, accumulatorL
			cpi temp1, low(1000) 					; if < 1000, display thousands digit
			ldi temp1, high(1000)
			cpc accumulatorH, temp1
			brlo display1000s

			mov temp1, accumulatorL					; decrement parameter by 1000
			subi temp1, low(1000)
			mov accumulatorL, temp1
			mov temp1, accumulatorH
			sbci temp1, high(1000)
			mov accumulatorH, temp1
		   
			lds temp1, digit4 						; increment thousands digit counter
			inc temp1
			sts digit4, temp1
		   
			jmp loop1000s
	   
		display1000s:
			lds temp1, digit4 						; print if thousands digit counter > 0
			cpi temp1, 0
			breq write100s

			lds temp1, isPrinted 					; set isPrinted to 1
			ldi temp1, 1
			sts isPrinted, temp1

			lds temp1, digit4 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1

			jmp write100s

		space1000s:
			lds temp1, isPrinted
			cpi temp1, 0
			breq write100s
			do_lcd_command_reg address
			inc address
			do_lcd_data '0'

	write100s:
		mov temp1, accumulatorL
		cpi temp1, low(100) 						; check that accumulatorH:accumulatorL > 100
		ldi temp1, high(100)
		cpc accumulatorH, temp1
		brlo space100s

		loop100s:
			mov temp1, accumulatorL
			cpi temp1, low(100) 					; if < 100, display hundreds digit
			ldi temp1, high(100)
			cpc accumulatorH, temp1
			brlo display100s

			mov temp1, accumulatorL					; decrement parameter by 100
			subi temp1, low(100)
			mov accumulatorL, temp1
			mov temp1, accumulatorH
			sbci temp1, high(100)
			mov accumulatorH, temp1
		   
			lds temp1, digit3 						; increment hundreds digit counter
			inc temp1
			sts digit3, temp1

			jmp loop100s
	   
		display100s:
			lds temp1, digit3 						; only print if hundreds digit counter > 0
			cpi temp1, 0
			breq write10s

			lds temp1, isPrinted 					; set isPrinted to 1
			ldi temp1, 1
			sts isPrinted, temp1

			lds temp1, digit3 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1

			jmp write10s
		
		space100s:
			lds temp1, isPrinted
			cpi temp1, 0
			breq write10s
			do_lcd_command_reg address
			inc address
			do_lcd_data '0'

	write10s:
		mov temp1, accumulatorL
		cpi temp1, 10 								; check that accumulatorH:accumulatorL >= 10
		brlo space10s

		loop10s:
			mov temp1, accumulatorL
			cpi temp1, 10 							; if < 10, display tens digit
			brlo display10s

			mov temp1, accumulatorL					; decrement parameter by 10
			subi temp1, low(10)
			mov accumulatorL, temp1
			mov temp1, accumulatorH
			sbci temp1, high(10)
			mov accumulatorH, temp1

			lds temp1, digit2 						; increment tens digit counter
			inc temp1
			sts digit2, temp1
		   
			jmp loop10s
	   
		display10s:
			lds temp1, digit2 						; only print if tens digit counter > 0
			cpi temp1, 0
			breq write1s

			lds temp1, digit2 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1
			jmp write1s

		space10s:
			lds temp1, isPrinted
			cpi temp1, 0
			breq write1s
			do_lcd_command_reg address
			inc address
			do_lcd_data '0'

	write1s:										; write remaining digit to LCD
		mov temp1, accumulatorL
		subi temp1, -'0' 							; convert to ASCII
		do_lcd_command_reg address
		inc address	
		do_lcd_data_reg temp1

	write16Epilogue:
	pop temp1
	pop accumulatorL
	pop accumulatorH
	ret

; Divides accumulatorL by currentL, and clears their high bytes
divide:
	push temp1

	clr temp1
	sts divideResult, temp1

	canDivide: 										; if accumulatorL < currentL we have finished
		cp accumulatorL, currentL
		brlo divideEpilogue

	divideLoop:
		sub accumulatorL, currentL					; accumulatorL = accumulatorL - currentL
		lds temp1, divideResult 					; divideResult++
		inc temp1
		sts divideResult, temp1
		jmp canDivide

	divideEpilogue:
	sts divideRem, accumulatorL
	lds accumulatorL, divideResult 					; store divideResult into accumulatorL
	clr accumulatorH
	clr currentH

	pop temp1
	ret