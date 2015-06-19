.include "m2560def.inc"
.include "top.asm" 									; contains macros, definitions and data segment variables

.cseg
.org 0x0000
	jmp RESET
	jmp RIGHT_BUTTON				; IRQ0 handled - connect PB0 to INT0 (RDX4) in Port D
	jmp LEFT_BUTTON					; IRQ1 handled - connect PB1 to INT1 (RDX3) in Port D
	jmp HOLES 						; IRQ2 Handler
	jmp DEFAULT 					; IRQ3 Handler
	jmp DEFAULT 					; IRQ4 Handler
	jmp DEFAULT 					; IRQ5 Handler
	jmp DEFAULT 					; IRQ6 Handler
	jmp DEFAULT 					; IRQ7 Handler
	jmp DEFAULT 					; Pin Change Interrupt Request 0
	jmp DEFAULT 					; Pin Change Interrupt Request 1
	jmp DEFAULT 					; Pin Change Interrupt Request 2
	jmp DEFAULT 					; Watchdog Time-out Interrupt
	jmp DEFAULT 					; Timer/Counter2 Compare Match A
	jmp DEFAULT 					; Timer/Counter2 Compare Match B
	jmp Timer2OVF 					; Timer/Counter2 Overflow
	jmp DEFAULT 					; Timer/Counter1 Capture Event
	jmp Timer1CMA 					; Timer/Counter1 Compare Match A
	jmp DEFAULT 					; Timer/Counter1 Compare Match B
	jmp DEFAULT 					; Timer/Counter1 Compare Match C
	jmp DEFAULT 					; Timer/Counter1 Overflow
	jmp DEFAULT 					; Timer/Counter0 Compare Match A
	jmp DEFAULT 					; Timer/Counter0 Compare Match B
	jmp Timer0OVF 					; Timer/Counter0 Overflow
	jmp DEFAULT 					; SPI Serial Transfer Complete
	jmp DEFAULT 					; USART0, Rx Complete
	jmp DEFAULT 					; USART0 Data register Empty
	jmp DEFAULT 					; USART0, Tx Complete
	jmp DEFAULT 					; Analog Comparator
	jmp DEFAULT 					; ADC Conversion Complete
	jmp DEFAULT 					; EEPROM Ready
	jmp DEFAULT 					; Timer/Counter3 Capture Event
	jmp DEFAULT 					; Timer/Counter3 Compare Match A
	jmp DEFAULT 					; Timer/Counter3 Compare Match B
	jmp DEFAULT 					; Timer/Counter3 Compare Match C
	jmp DEFAULT 					; Timer/Counter3 Overflow
.org 0x0072
DEFAULT:
	reti							; used for interrupts that are not handled

RESET:
	ldi param, low(RAMEND)
	out SPL, param
	ldi param, high(RAMEND)
	out SPH, param

	clr param
	out DDRD, param 								; set PORTD (INT0/1) to input (buttons)

	ser param 										
	out DDRF, param 								; set PORTF and PORTA to output (LCD)
	out DDRA, param
	out DDRC, param 								; set PORTC to output (LEDs)
	out DDRB, param 								; set PORTB to output (speaker)

	clr param										; clear PORTF and PORTA registers
	out PORTF, param 								; clear PORTF
	out PORTA, param 								; clear PORTA
	out PORTC, param 								; clear PORTC
	out PORTD, param 								; clear PORTD

	ldi temp1, PORTLDIR								; set PL7:4 to output and PL3:0 to input (keypad)
	sts DDRL, temp1
	com temp1
	sts PORTL, temp1

	ser temp1										; set PORTH to output (Backlight + Door Open LED)
	sts DDRH, temp1
	clr temp1										; clear PORTH
	sts PORTH, temp1								

	rcall initialiseLCD
	rcall initialiseTurntable
	rcall initialiseMotor
	rcall initialiseButtons
	rcall initialiseBacklightTimer
	rcall initialiseFinishedSounds

	clr temp1 										; initialise variables
	sts currPress, temp1
	sts wasPress, temp1
	sts mode, temp1
	sts minutes, temp1
	sts seconds, temp1
	sts numberEnteredDigits, temp1
	sts enteredDigits, temp1
	sts enteredDigits + 1, temp1
	sts enteredDigits + 2, temp1
	sts enteredDigits + 3, temp1
	ldi temp1, DOOR_CLOSED
	sts door, temp1

	do_lcd_command LCD_DOOR_ICON 					; write C to bottom-right corner of LCD (closed door)
	do_lcd_data 'C'

main:
	checkDoorOpen:
	lds temp1, door
	cpi temp1, DOOR_OPEN
	breq checkDoorOpen

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
	ori cmask, 0x0F
	sts PORTL, cmask								; otherwise, scan a column

	ldi temp1, 0xFF									; slow down the scan operation to debounce button press
	delay:
	dec temp1
	brne delay

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
	rcall backlightFadeIn
	rcall keypress

	ldi temp1, 1 									; set currPress = 1
	sts currPress, temp1
	lds temp1, wasPress 							; if wasPress = 1, ignore keypad press
	cpi temp1, 1
	breq main

	cpi col, 3										; if the pressed key is in col.3 
	jeq letters										; we have a letter
	cpi row, 3										; if the key is not in col 3 and is in row 3,
	jeq symbols										; we have a symbol or 0
	mov temp1, row 									; otherwise we have a number in 1-9
	lsl temp1 										; multiply temp1 by 2
	add temp1, row 									; add row again to temp1 -> temp1 = row * 3
	add temp1, col 									; temp1 = col*3 + row
	inc temp1
	sts keypadNumber, temp1

number:
	lds temp2, mode
	cpi temp2, ENTRY
	breq numberEntry
	cpi temp2, POWER
	breq numberPower
	rjmp numberEnd

	numberEntry: 									; set timer
		lds temp1, numberEnteredDigits
		cpi temp1, 4
		jeq numberEnd
		cpi temp1, 0
		brne storeEnteredNumber
		lds temp1, keypadNumber
		cpi temp1, 0
		brne storeEnteredNumber
		jmp numberEnd	 							; if numberEnteredDigits == 0  && keypadNumber == 0, ignore keypress
		
		storeEnteredNumber:
		
		lds temp1, numberEnteredDigits
		clr XL
		clr XH
		ldi XL, low(enteredDigits) 					; store keypadNumber in enteredDigits + numberEnteredDigits
		ldi XH, high(enteredDigits)
		add XL, temp1
		ldi temp2, 0
		adc XH, temp2
		lds temp2, keypadNumber
		st X, temp2

		lds temp1, numberEnteredDigits
		inc temp1
		sts numberEnteredDigits, temp1 				; numberEnteredDigits = numberEnteredDigits + 1
		rcall dispEnteredDigits  					; display digits in format mm:ss with leading zeros

		jmp numberEnd
	numberPower:									; set power if number is 1/2/3
		
		cpi row, 0 									; if row != 0, it is not 1/2/3 so go to numberEnd
		jne numberEnd

		cpi col, 1 									; if col = 1, number is 2
		jeq numberPower2
		cpi col, 2 									; if col = 2, number is 3
		jeq numberPower3 							; else if col = 0, number is 1
			ldi temp2, LEDS_POWER1
			ldi temp1, 1 							; set Power to 1
			jmp numberPowerEnd
		numberPower2:
			ldi temp2, LEDS_POWER2
			ldi temp1, 2 							; set Power to 2
			jmp numberPowerEnd
		numberPower3:
			ldi temp2, LEDS_POWER3
			ldi temp1, 3 							; set Power to 3

		numberPowerEnd:
			sts PowerValue, temp1
			out PORTC, temp2

	numberEnd:
	jmp main

letters:
	cpi row, 0
	breq APress 									; if row 0, A was pressed
	cpi row, 2
	breq CPress 									; if row 2, C was pressed
	cpi row, 3
	breq DPress 									; if row 3, D was pressed
	jmp main 										; otherwise, B was pressed so ignore and return to keypad scan

symbols:
	cpi col, 0 										; if its in column 0, it's a star
	jeq star
	cpi col, 1 										; if its in column 1, it's a zero
	jeq zero
	cpi col, 2 										; if its column 2, it's a hash
	jeq hash
	jmp main

APress:
	lds temp1, mode
	cpi temp1, ENTRY 								; if current mode is ENTRY, change to POWER
	brne APressEnd
	ldi temp1, POWER
	sts mode, temp1
	rcall dispPowerText 							; display 'Set Power 1/2/3'
	

	APressEnd:
	jmp main

CPress:
	lds temp1, mode
	cpi temp1, RUNNING
	brne cPressEnd
	
	ldi temp1, 30								; + 30s to timer, don't change mode
	rcall addSeconds
	

	cPressEnd:
	jmp main

DPress:
	lds temp1, mode
	cpi temp1, RUNNING
	brne dPressEnd

	ldi temp1, 30								; -30 to timer, don't change mode
	rcall subtractSeconds
	

	dPressEnd:
	jmp main
	
zero:
	ldi temp1, 0
	sts keypadNumber, temp1
	jmp number

star:
	lds temp1, mode
	cpi temp1, ENTRY
	breq starEntry
	cpi temp1, RUNNING
	breq starRunning
	cpi temp1, PAUSED
	breq starPaused
	rjmp starEnd

	starEntry:
		ldi temp1, RUNNING 							; if current mode is ENTRY, set to RUNNING
		sts mode, temp1
		rcall startRunning
		
		jmp starEnd
	starRunning:
		ldi temp2, 1
		rcall addMinutes
		
		jmp starEnd
	starPaused:
		ldi temp1, RUNNING 							; if current mode is PAUSED, set to RUNNING
		sts mode, temp1
		rcall startTurntableMotor					; resume timer
		
		jmp starEnd

	starEnd:
	jmp main

hash:
	lds temp1, mode
	cpi temp1, POWER
	breq hashPower
	cpi temp1, ENTRY
	jeq hashEntry
	cpi temp1, PAUSED
	jeq hashPaused
	cpi temp1, RUNNING
	jeq hashRunning
	cpi temp1, FINISHED
	jeq hashFinished

	hashPower:
		ldi temp1, ENTRY 							; if current mode is POWER, set to ENTRY
		sts mode, temp1
		do_lcd_command LCD_FIRST_LINE				; clear power text
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
		do_lcd_data ' '
		do_lcd_data ' '
		do_lcd_data ' '
		do_lcd_data ' '
		do_lcd_command LCD_FIRST_LINE
		rcall dispEnteredDigits 					; if numberEnteredDigits != 0, display entered digits
		
		jmp hashEnd
	hashEntry:
		rcall clearTimeText							; clear time from lcd
		clr temp1 									; clear enteredDigits and numberEnteredDigits
		sts numberEnteredDigits, temp1
		sts enteredDigits, temp1
		sts enteredDigits + 1, temp1
		sts enteredDigits + 2, temp1
		sts enteredDigits + 3, temp1
		
		jmp hashEnd
	hashPaused:
		rcall clearTimeText							; clear time from lcd
		clr temp1									; clear time
		sts minutes, temp1	
		sts seconds, temp1
	
		clr temp1										; clear entered digits
		sts enteredDigits, temp1
		sts enteredDigits + 1, temp1
		sts enteredDigits + 2, temp1
		sts enteredDigits + 3, temp1
		sts numberEnteredDigits, temp1					; clear number entered digits

		ldi temp1, ENTRY 							; if current mode is PAUSED, set to ENTRY
		sts mode, temp1
		
		jmp hashEnd
	hashRunning:
		rcall stopTurntableMotor
		ldi temp1, PAUSED 							; if current mode is RUNNING, set to PAUSED
		sts mode, temp1
		
		jmp hashEnd
	hashFinished:
		rcall clearFinishedText						; clear finished text from lcd
		ldi temp1, ENTRY 							; if current mode is FINISHED, set to ENTRY
		sts mode, temp1
		

	hashEnd:
	jmp main

LEFT_BUTTON:
	push temp1
	in temp1, SREG
	push temp1

	ldi temp1, DOOR_OPEN 							; open door
	sts door, temp1

	ldi temp1, DOOR_LIGHT_MASK						; turn on door led
	sts PORTH, temp1

	;rcall backlightFadeIn							; backlight fade in
	
	do_lcd_command LCD_DOOR_ICON 					; write O to indicator
	do_lcd_data 'O'

	lds temp1, mode
	cpi temp1, RUNNING
	breq LEFT_BUTTON_RUNNING
	cpi temp1, FINISHED
	breq LEFT_BUTTON_FINISHED
	rjmp LEFT_BUTTON_END

	LEFT_BUTTON_RUNNING:
		ldi temp1, PAUSED 							; if current mode is RUNNING, set to PAUSED
		sts mode, temp1
		rcall stopTurntableMotor
		jmp LEFT_BUTTON_END
	LEFT_BUTTON_FINISHED:
		ldi temp1, ENTRY 							; if current mode is FINISHED, set to ENTRY
		sts mode, temp1
		rcall clearFinishedText						; clear finished text from lcd
		jmp LEFT_BUTTON_END

	LEFT_BUTTON_END:
	pop temp1
	out SREG, temp1
	pop temp1
	reti

RIGHT_BUTTON:
	push temp1
	in temp1, SREG
	push temp1

	ldi temp1, DOOR_CLOSED 							; close door
	sts door, temp1

	clr temp1										; turn off door led
	sts PORTH, temp1
	;rcall backlightFadeIn							; backlight fade in
	
	do_lcd_command LCD_DOOR_ICON 					; write C to indicator
	do_lcd_data 'C'

	pop temp1
	out SREG, temp1
	pop temp1
	reti

HOLES: 												; counts number of holes passed in motor
	push temp1
	push temp2
	in temp1, SREG
	push temp1

	lds temp1, rps 									; rps++
	ldi temp2, 1
	add temp1, temp2 								; rps += 1
	sts rps, temp1
	
	HOLES_EPILOGUE:
	pop temp1
	out SREG, temp1
	pop temp2
	pop temp1
	reti

Timer0OVF:											; interrupt subroutine to Timer0
	push temp1
	push temp2
	in temp1, SREG
	push temp1 										; save conflict registers
	push r25
	push r24

	lds r24, TempCounter 							; load value of temporary counter
	lds r25, TempCounter + 1
	adiw r25:r24, 1 								; increase temporary counter by 1

	cpi r24, low(3906)								; check if 0.5 seconds have passed
	ldi temp1, high(3906)
	cpc r25, temp1
	breq pc+2 										; if they're not equal, jump to checkSecond
	jmp checkSecond 								; here we know 0.5 seconds have passed
	rcall nextTurntableFrame 						; calls function that animate turntable every 2.5 seconds
	rcall adjustRPS 								; adjust motor rps

	checkSecond:
	cpi r24, low(7812)								; here use 7812 = 10^6/128 for 1 second
	ldi temp1, high(7812) 							; use 3906 for 0.5 seconds, 1953 for 0.25s
	cpc r25, temp1
	breq pc+2 										; if they're not equal, jump to notSecond
	jmp notSecond 									; here we know 1 second has passed
	
	lds temp1, seconds								; decrement time
	cpi temp1, 0									; check if seconds equal 0
	breq zeroSeconds
	
	dec temp1										; decrement the seconds and store
	sts seconds, temp1
	rcall dispMinutesSeconds
	rjmp notFive

	zeroSeconds:										; if seconds = 0
		lds temp1, minutes
		cpi temp1, 0									; check if minutes are also 0
		breq timeFinished
		dec temp1										; decrement minutes
		sts minutes, temp1								; store minutes
		ldi temp1, 59									; set seconds to 59
		sts seconds, temp1								; store seconds
		rcall dispMinutesSeconds 						; display new time
		rjmp notFive

	timeFinished:										; if seconds = 0 and minutes = 0
		rcall doFinished
		rjmp epilogue

	notFive:
		rcall nextTurntableFrame 					; calls function that animates turntable every 2.5 seconds
		clr temp1
		sts TempCounter, temp1						; reset temporary counter
		sts TempCounter + 1, temp1
		
		lds temp1, PowerValue
		cpi temp1, 1
		breq epilogue

		ldi temp1, low(RPS)							; turn motor back on
		sts OCR3AH, temp1
		ldi temp1, high(RPS)
		sts OCR3AL, temp1

		rjmp epilogue

	notSecond:
		lds temp1, PowerValue
		cpi temp1, 1
		breq storeTempCounter
		cpi temp1, 2
		breq powerIsTwo

		powerIsThree:
		cpi r24, low(1953)			 				; 1953 for 0.25s
		ldi temp1, high(1953)
		cpc r25, temp1
		brne storeTempCounter
		jmp turnOffMotor

		powerIsTwo:
		cpi r24, low(3906)							; 3906 for 0.5 seconds
		ldi temp1, high(3906)
		cpc r25, temp1
		brne storeTempCounter

		turnOffMotor: 								; turn off motor if power level is 2/3 after 0.5/0.25s
		clr temp1
		sts OCR3AH, temp1
		sts OCR3AL, temp1

	storeTempCounter:
		sts TempCounter, r24						; store new value of temporary counter
		sts TempCounter + 1, r25

	epilogue:
		pop r24
		pop r25
		pop temp1
		out SREG, temp1
		pop temp2
		pop temp1
		reti

Timer1CMA:
	push temp1
	push temp2
	push temp3
	in temp1, SREG
	push temp1

	lds temp1, mode									; cancel beeps if we have left FINISHED mode
	cpi temp1, ENTRY
	breq Timer1CMAStop

	clr temp1 										; prevents overlaps in interrupts
	sts TCNT1H, temp1
	sts TCNT1L, temp1

	Timer1CMALoop:
		rcall checkHash 							; poll hash key
		lds temp1, mode								; cancel beeps if we have left FINISHED mode
		cpi temp1, ENTRY
		breq Timer1CMAStop

		lds temp1, finishedBeepCounter 				; loop 350 times - beep for ~1s
		lds temp2, finishedBeepCounter + 1
		ldi temp3, 1
		add temp1, temp3
		ldi temp3, 0
		adc temp2, temp3
		sts finishedBeepCounter, temp1 				; finishedBeepCounter += 1
		sts finishedBeepCounter + 1, temp2

		cpi temp1, low(400) 						; compare finishedBeepCounter to 400
		ldi temp3, high(400)
		cpc temp2, temp3
		breq Timer1CMAEndBeep 						; if equal, stop making sound

		sbi PORTB, 0  								; make sound
		rcall sleep_1ms
		cbi PORTB, 0
		rcall sleep_1ms
		rjmp Timer1CMALoop

	Timer1CMAEndBeep:
	clr temp1 										; initialise counter
	sts finishedBeepCounter, temp1
	sts finishedBeepCounter + 1, temp1

	lds temp1, finishedSoundCounter 				; finishedSoundCounter += 1
	inc temp1
	sts finishedSoundCounter, temp1
	cpi temp1, 3 									; if we have generated 3 beeps, we are done
	breq Timer1CMAStop

	clr temp1 										; ensures next interrupt occurs in 1s
	sts TCNT1H, temp1
	sts TCNT1L, temp1
	jmp Timer1CMAEpilogue
	
	Timer1CMAStop:
		ldi temp1, (0 << OCIE1A) 					; disable interrupt on compare match
		sts TIMSK1, temp1

	Timer1CMAEpilogue:
	pop temp1
	out SREG, temp1
	pop temp3
	pop temp2
	pop temp1
	reti

Timer2OVF:									; interrupt subroutine timer 2
	push temp1
	push temp2
	in temp1, SREG
	push temp1
	push r24
	push r25	

	lds r24, BacklightFadeCounter			; load the backlight fade counter
	inc r24									; increment the counter
	sts BacklightFadeCounter, r24
	cpi r24, 30								; check if has been 1sec/0xFF
	brne fadeFinished
	
	clr temp1								; reset fade counter
	sts BacklightFadeCounter, temp1	

	lds temp1, BacklightFade				; check what fade state
	cpi temp1, LCD_BACKLIGHT_FADEIN
	breq fadeIn
	cpi temp1, LCD_BACKLIGHT_FADEOUT
	breq fadeOut
	rjmp fadeFinished

	fadeIn:									; if fading in
		lds temp2, BacklightPWM
		cpi temp2, 0xFF						; check if already max brightness
		breq lcdBacklightMax
		inc temp2							; inc pwm
		sts BacklightPWM, temp2				; store new pwm
		rjmp dispLCDBacklight		

		lcdBacklightMax:
			ldi temp1, LCD_BACKLIGHT_STABLE	; set to stable pwm
			sts BacklightFade, temp1		; store new fade state
			rjmp fadeFinished

	fadeOut:
		lds temp2, BacklightPWM				; if fading out
		cpi temp2, 0x00						; check if min brightness
		breq lcdBacklightMin
		dec temp2							; dec pwm
		sts BacklightPWM, temp2				;store new pwm
		rjmp dispLCDBacklight

		lcdBacklightMin:
			ldi temp1, LCD_BACKLIGHT_STABLE
			sts BacklightFade, temp1
			rjmp fadeFinished

	dispLCDBacklight:
		lds temp1, BacklightPWM
		sts OCR4AL, temp1
		clr temp1
		sts OCR4AH, temp1	
	
	fadeFinished:
	; if running the backlight should remain on
	lds temp1, mode							; load the mode
	cpi temp1, RUNNING						; check if running
	breq timer2Epilogue
		
	lds r24, BacklightCounter				; load the backlight counter
	lds r25, BacklightCounter+1
	adiw r25:r24, 1							; increment the counter
		
	sts BacklightCounter, r24				; store new values
	sts BacklightCounter+1, r25

	cpi r24, low(7812)						; check if it has been 1 second
	ldi temp1, high(7812)
	cpc r25, temp1
	brne timer2Epilogue
	
	clr temp1								; clear the counter
	sts BacklightCounter, temp1
	sts BacklightCounter+1, temp1

	lds r24, BacklightSeconds				; load backlight seconds
	inc r24									; increment the baclight seconds
	sts BacklightSeconds, r24				; store new value

	cpi r24, 10								; check if it has been 10 seconds
	brne timer2Epilogue
	
	clr temp1								; reset the seconds
	sts BacklightSeconds, temp1

	clr temp2
	lds temp1, door
	cpi temp1, 0
	breq fadeOutBacklight
	ldi temp2, DOOR_LIGHT_MASK	

	fadeOutBacklight:						; start fading out the backlight
		rcall backlightFadeOut
		
	timer2Epilogue:
	pop r25
	pop r24
	pop temp1
	out SREG, temp1
	pop temp2
	pop temp1
	reti

; These files contain helper functions as well as some definitions
.include "buttons.asm"
.include "modehelper.asm"
.include "timerarith.asm"
.include "turntablemagnetron.asm"
.include "speaker.asm"
.include "lcdbacklight.asm"
.include "lcd.asm"
.include "delay.asm"
