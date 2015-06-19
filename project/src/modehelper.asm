startRunning:
	push temp1
	push temp2
	push XL
	push XH

	; convert digits into minutes and seconds
	ldi XL, low(enteredDigits)			; set X to first digit of enteredDigits
	ldi XH, high(enteredDigits)

	lds temp1, numberEnteredDigits
	cpi temp1, 0
	breq convertTime0
	cpi temp1, 1
	breq convertTime1
	cpi temp1, 2
	breq convertTime2
	cpi temp1, 3
	breq convertTime3

	convertTime4:					; convert the 4th digit
		ld temp1, X+				; load the 4th digit
		mov temp2, temp1
		lsl temp1					; times by 10
		lsl temp1
		lsl temp1
		add temp1, temp2
		add temp1, temp2
		sts minutes, temp1			; store to minutes								

	convertTime3:						; convert the 3rd digit
		ld temp1, X+ 					; load the 3rd digit
		lds temp2, minutes				; load minutes
		add temp1, temp2				; add the 3rd digit to minutes
		sts minutes, temp1				; store to minutes

	convertTime2:						; convert the 2nd digit
		ld temp1, X+						; load the 2nd digit
		mov temp2, temp1				; times by 10
		lsl temp1
		lsl temp1
		lsl temp1
		add temp1, temp2
		add temp1, temp2
		sts seconds, temp1				; store to seconds


	convertTime1:						; convert the 1st digit
		ld temp1, X						; load the 1st digit
		lds temp2, seconds				; load the seconds
		add temp1, temp2				; add 1st digit to seconds
		sts seconds, temp1				; store the seconds
		rjmp startCountDownTimer

	convertTime0:	; no digits entered - add 1 minute
		ldi temp1, 1
		sts minutes, temp1
		rcall dispMinutesSeconds

	startCountDownTimer:
		lds temp1, TurntableDirection 					; change turntable direction
		cpi temp1, 1
		brne startRunningTurntable
		ldi temp2, 0 									; if TurntableDirection == 1, set to 0
		jmp startRunningStore
		startRunningTurntable:
		ldi temp2, 1 									; if TurntableDirection == 0, set to 1
		startRunningStore:
		sts TurntableDirection, temp2

		rcall startTurntableMotor 						; turn on Turntable and Motor

	startRunningEpilogue:
	pop XH
	pop XL
	pop temp2
	pop temp1
	ret

doFinished:
	push temp1

	ldi temp1, FINISHED 							; change the mode to FINISHED
	sts mode, temp1

	rcall stopTurntableMotor 						; stop the turntable animation and the motor
	rcall finishedSounds 							; play 3 beeps

	clr temp1										; clear entered digits
	sts enteredDigits, temp1
	sts enteredDigits + 1, temp1
	sts enteredDigits + 2, temp1
	sts enteredDigits + 3, temp1
	sts numberEnteredDigits, temp1					; clear number entered digits

	do_lcd_command LCD_FIRST_LINE 					; display 'Done' on first line
	do_lcd_data 'D'
	do_lcd_data 'o'
	do_lcd_data 'n'
	do_lcd_data 'e'
	do_lcd_data ' '
	do_lcd_command LCD_SEC_LINE 					; display 'Remove food' on second line	
	do_lcd_data 'R'
	do_lcd_data 'e'
	do_lcd_data 'm'
	do_lcd_data 'o'
	do_lcd_data 'v'
	do_lcd_data 'e'
	do_lcd_data ' '
	do_lcd_data 'F'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'd'

	pop temp1
	ret
