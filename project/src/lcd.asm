
; LCD Functions
initialiseLCD: 										; used to initialise LCD and related variables
	push temp1

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

	clr temp1 										; clear digits for write8 function
	sts digits, temp1
	sts digits + 1, temp1
	sts digits + 2, temp1
	sts digits + 3, temp1

	pop temp1
	ret

dispEnteredDigits: 									; displays entered timer digits if digits have been entered
	push temp1
	in temp1, SREG
	push temp1
	cli 											; prevents unusual LCD displays due to interrupts

	lds temp1, numberEnteredDigits 					; branch to the appropriate code based on the number of entered digits
	cpi temp1, 0
	jeq dispEnteredDigitsEpilogue
	cpi temp1, 2
	jeq dispEnteredDigits2
	cpi temp1, 3
	jeq dispEnteredDigits3
	cpi temp1, 4
	jeq dispEnteredDigits4

	dispEnteredDigits1: 							; only one digit is entered
		do_lcd_command LCD_FIRST_LINE 				; print 0
		do_lcd_data '0'
		do_lcd_command LCD_FIRST_LINE + 1 			; print 0
		do_lcd_data '0'
		do_lcd_command LCD_COLON 					; print :
		do_lcd_data ':'
		do_lcd_command LCD_START_TIME - 1 			; print 0
		do_lcd_data '0'
		do_lcd_command LCD_START_TIME 				; convert entered digit to ASCII
		lds temp1, enteredDigits
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print entered digit
		jmp dispEnteredDigitsEpilogue

	dispEnteredDigits2: 							; two digits are entered
		do_lcd_command LCD_FIRST_LINE 				; print 0
		do_lcd_data '0'
		do_lcd_command LCD_FIRST_LINE + 1 			; print 0
		do_lcd_data '0'
		do_lcd_command LCD_COLON 					; print :
		do_lcd_data ':'
		do_lcd_command LCD_START_TIME - 1 			; convert first entered digit to ASCII
		lds temp1, enteredDigits
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print first entered digit
		do_lcd_command LCD_START_TIME 				; convert second entered digit to ASCII
		lds temp1, enteredDigits + 1
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print second entered digit
		jmp dispEnteredDigitsEpilogue

	dispEnteredDigits3: 							; three digits are entered
		do_lcd_command LCD_FIRST_LINE 				; print 0
		do_lcd_data '0'
		do_lcd_command LCD_FIRST_LINE + 1 			; convert first entered digit to ASCII
		lds temp1, enteredDigits
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print first entered digit
		do_lcd_command LCD_COLON 					; print :
		do_lcd_data ':'
		do_lcd_command LCD_START_TIME - 1 			; convert second entered digit to ASCII
		lds temp1, enteredDigits + 1
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print second entered digit
		do_lcd_command LCD_START_TIME 				; convert third entered digit to ASCII
		lds temp1, enteredDigits + 2
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print third entered digit
		jmp dispEnteredDigitsEpilogue

	dispEnteredDigits4:
		do_lcd_command LCD_FIRST_LINE 				; convert first entered digit to ASCII
		lds temp1, enteredDigits
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1						; print first entered digit
		do_lcd_command LCD_FIRST_LINE + 1 			; convert second entered digit to ASCII
		lds temp1, enteredDigits + 1
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print second entered digit
		do_lcd_command LCD_COLON 					; print :
		do_lcd_data ':'
		do_lcd_command LCD_START_TIME - 1 			; convert third entered digit to ASCII
		lds temp1, enteredDigits + 2
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print third entered digit
		do_lcd_command LCD_START_TIME 				; convert fourth entered digit to ASCII
		lds temp1, enteredDigits + 3
		ldi temp2, '0'
		add temp1, temp2
		do_lcd_data_reg temp1 						; print fourth entered digit

	dispEnteredDigitsEpilogue:
	pop temp1
	out SREG, temp1
	pop temp1
	ret

dispMinutesSeconds:
	push temp1
	push temp2
	push param
	push YH
	push YL
	in temp1, SREG
	push temp1
	cli
	
	lds temp1, minutes				; load minutes
	clr temp2
	cpi temp1, 10
	brlo printMinutes
	checkMins:						; subtract 10 from minutes until it equals zero
		inc temp2					; the number of subtractions is the number of 10s
		subi temp1, 10
		cpi temp1, 10
		brsh checkMins
		
	printMinutes:						; print the minutes
		do_lcd_command LCD_FIRST_LINE
		ldi param, '0'					; add '0' to get ASCII value
		add temp2, param
		do_lcd_data_reg temp2			; print the 10s
	
		do_lcd_command LCD_FIRST_LINE+1	; the left over minutes will be the 1s
		ldi param, '0'					; add '0' to get ASCII value
		add temp1, param
		do_lcd_data_reg temp1			; print the 1s

		do_lcd_command LCD_COLON		; print the colon
		do_lcd_data ':'

		lds temp1, seconds				; load seconds
		clr temp2
		cpi temp1, 10
		brlo printSeconds
	checkSecs:						; subtract 10 from seconds until it equals zero
		inc temp2					; the number of subtractions is the number of 10s
		subi temp1, 10
		cpi temp1, 10
		brsh checkSecs

	printSeconds:
		do_lcd_command LCD_START_TIME-1
		ldi param, '0'					; add '0' to get ASCII value
		add temp2, param
		do_lcd_data_reg temp2			; print the number of 10s

		do_lcd_command LCD_START_TIME	; left over seconds will be the 1s
		ldi param, '0'					; add '0' to get ASCII value
		add temp1, param
		do_lcd_data_reg temp1			; print the number of 1s

	pop temp1
	out SREG, temp1
	pop YL
	pop YH
	pop param
	pop temp2
	pop temp1
	ret

dispPowerText: 										; displays text associated with POWER mode
	do_lcd_command LCD_FIRST_LINE
	do_lcd_data 'S'
	do_lcd_data 'e'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'P'
	do_lcd_data 'o'
	do_lcd_data 'w'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data ' '
	do_lcd_data '1'
	do_lcd_data '/'
	do_lcd_data '2'
	do_lcd_data '/'
	do_lcd_data '3'
	ret

clearTimeText: 										; used to clear the LCD without overwriting the turntable and door indicator
	do_lcd_command LCD_FIRST_LINE
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_command LCD_FIRST_LINE
	ret

clearFinishedText: 									; used to clear the LCD without overwriting the turntable and door indicator
	do_lcd_command LCD_FIRST_LINE
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_command LCD_SEC_LINE
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_command LCD_FIRST_LINE
	ret

write8: 											; writes temp1 onto LCD at given address
	push temp2
	in temp2, SREG
	push temp2
	cli

	cpi temp1, 100 									; check if initial number > 100 (3 digits)
	brsh endCheckHundreds
	clr temp2
	
	endCheckHundreds:
		sts digits + 1, temp2
	   
	writeHundreds:
		clr temp2									; set hundreds digit counter to 0
		sts digits, temp2
	   
		hundredsLoop:
			cpi temp1, 100 							; if < 100, display hundreds digit
			brlo displayHundreds
		   
			ldi temp2, 100 							; decrement parameter by 100
			sub temp1, temp2
		   
			lds temp2, digits 						; increment hundreds digit counter
			inc temp2
			sts digits, temp2
		   
			jmp hundredsLoop
	   
		displayHundreds:
			lds temp2, digits 						; only print if hundreds digit counter > 0
			cpi temp2, 0
			breq writeTens

			sts digits + 2, temp1 					; convert temp2 to ASCII
			mov temp1, temp2
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1
			lds temp1, digits + 2
	   
	writeTens:
		clr temp2 									; set tens digit counter to 0
		sts digits, temp2
	   
		tensLoop:
			cpi temp1, 10 							; if < 10, display tens digit
			brlo displayTens
		   
			ldi temp2, 10 							; decrement parameter by 10
			sub temp1, temp2
		   
			lds temp2, digits 						; increment tens digit counter
			inc temp2
			sts digits, temp2
		   
			jmp tensLoop
		   
		displayTens:
			lds temp2, digits 						; print if tens digit counter > 0 or if hundreds digit was printed
			cpi temp2, 0
			breq isHundredsWritten
		   
			actuallyDisplayTens:
				lds temp2, digits 					; convert to ASCII
				sts digits + 2, temp1
				mov temp1, temp2
				subi temp1, -'0'
				do_lcd_command_reg address
				inc address
				do_lcd_data_reg temp1
				lds temp1, digits + 2
				jmp writeOnes
		   
			isHundredsWritten:
				lds temp2, digits + 1
				cpi temp2, 255
				breq actuallyDisplayTens
   
	writeOnes:										; write remaining digit to lcd
		subi temp1, -'0' 							; convert to ASCII
		do_lcd_command_reg address
		inc address
		do_lcd_data_reg temp1

	pop temp2
	out SREG, temp2
	pop temp2
	ret

; Note: the following code was provided in the labs.

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