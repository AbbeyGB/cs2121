; Turntable and Magnetron functions
build_bslash: 										; Makes a custom backslash character for LCD as character 0
	do_lcd_command 0b01000000
	do_lcd_data 0b00000
	do_lcd_data 0b10000
	do_lcd_data 0b01000
	do_lcd_data 0b00100
	do_lcd_data 0b00010
	do_lcd_data 0b00001
	do_lcd_data 0b00000
	do_lcd_data 0b00000
	ret

initialiseTurntable:
	push temp1

	ldi temp1, '-' 									; load in turntable animation frames
	sts TurntableAnimation, temp1
	ldi temp1, '/'
	sts TurntableAnimation + 1, temp1
	ldi temp1, '|'
	sts TurntableAnimation + 2, temp1
	rcall build_bslash
	clr temp1 										; initialise variables
	sts TurntableAnimation + 3, temp1
	sts TurntableFrame, temp1
	sts TurntableSeconds, temp1
	sts TurntableDirection, temp1

	do_lcd_command LCD_TURNTABLE 					; print first frame to LCD
	do_lcd_data '-'

	clr temp1
	sts TempCounter, temp1 							; initialise temporary counter to 0
	sts TempCounter + 1, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1 								; set prescaler to 8 = 278 microseconds
	
	pop temp1
	ret

initialiseMotor:
	push temp1

	;ldi temp1, 0b00011000 							; set PE4 (OC3B) to output
	ser temp1
	out DDRE, temp1

	ldi temp1, (1 << CS30) 							; set the Timer3 to Phase Correct PWM mode. 
	sts TCCR3B, temp1
	ldi temp1, (1 << WGM31)|(1<< WGM30)|(1<<COM3B1)|(1<<COM3A1)
	sts TCCR3A, temp1

	ldi temp1, 1 									; initialise the power variable
	sts PowerValue, temp1
	ldi temp1, LEDS_POWER1 							; set the LEDS to the first power level
	out PORTC, temp1

	clr temp1
	sts rps, temp1

	pop temp1
	ret

startTurntableMotor:
	push temp1
	
	ldi temp1, 1 << TOIE0 							; enable timer
	sts TIMSK0, temp1
	ldi temp1, low(INIT_RPS)						; start motor
	sts OCR3AH, temp1
	ldi temp1, high(INIT_RPS)
	sts OCR3AL, temp1
	
	pop temp1
	ret

stopTurntableMotor:
	push temp1
	
	ldi temp1, 0 << TOIE0 							; disable timer
	sts TIMSK0, temp1
	clr temp1										; stop motor
	sts OCR3AH, temp1
	sts OCR3AL, temp1
	
	pop temp1
	ret

nextTurntableFrame:
	push temp1
	push XL
	push XH
	
	lds temp1, TurntableSeconds 					; change animation
	inc temp1
	sts TurntableSeconds, temp1
	cpi temp1, 5 									; if TurntableSeconds == 5, go to next frame
	brne nextTurntableFrameEpilogue

	clr temp1 										; clear TurntableSeconds
	sts TurntableSeconds, temp1

	lds temp1, TurntableDirection
	cpi temp1, 1
	brne clockwise

	; if TurntableDirection == 1, spin CCW (increment through frames)
		lds temp1, TurntableFrame 					; TurntableFrame = (TurntableFrame + 1) % FRAMES
		inc temp1
		andi temp1, FRAMES - 1
		jmp loadFrame

	clockwise: 										; else if TurntableDirection == 1, spin CW (decrement through frames)
		lds temp1, TurntableFrame 					; TurntableFrame = (TurntableFrame + 1) % FRAMES
		cpi temp1, 0 								; if 0, TurntableFrame = 3
		breq clockwiseZero
		dec temp1									; else decrement TurntableFrame
		jmp loadFrame
		clockwiseZero:
			ldi temp1, 3

	loadFrame:
		sts TurntableFrame, temp1
		ldi XL, low(TurntableAnimation)				; X = TurntableAnimation + TurntableFrame
		ldi XH, high(TurntableAnimation)
		lds temp1, TurntableFrame
		add XL, temp1
		ldi temp1, 0
		adc XH, temp1

		ld temp1, X 								; put next frame on LCD
		do_lcd_command LCD_TURNTABLE
		do_lcd_data_reg temp1

	nextTurntableFrameEpilogue:
	pop XH
	pop XL
	pop temp1
	ret

.equ targetrps = 75
.equ step = 5

adjustRPS:
	push temp1
	push temp2
	push temp3

	lds temp1, OCR3AL 								; check if OCR3AH:L == 0
	lds temp2, OCR3AH
	ldi temp3, 0
	cpi temp1, 0
	cpc temp2, temp3
	jeq adjustRPSEpilogue 							; if motor is off, do not adjust rps

	lds temp1, rps 									; need to multiply rps by 2 to give revolutions per SECOND
	lsr temp1										; need to divide by 4 to account for 4 holes -> divide by 2
	
	cpi temp1, targetrps
	breq adjustRPSEnd 								; if rps == targetrps go to adjustRPSEnd
	brsh adjustRPSDec 								; if rps > targetrps, go to adjustRPSDec
	
	lds temp1, OCR3AL 								; else we know rps < targetrps so increase OCR3B by step
	lds temp2, OCR3AH
	ldi temp3, step
	add temp1, temp3
	clr temp3
	adc temp2, temp3
	sts OCR3AH, temp2
	sts OCR3AL, temp1
	jmp adjustRPSEnd

	adjustRPSDec: 									; if rps > targetrps decrease OCR3B by step
	lds temp1, OCR3AL
	subi temp1, step
	lds temp2, OCR3AH
	sbci temp2, 0
	sts OCR3AH, temp2
	sts OCR3AL, temp1
	
	adjustRPSEnd:
	clr temp1
	sts rps, temp1

	adjustRPSEpilogue:
	pop temp3
	pop temp2
	pop temp1
	ret