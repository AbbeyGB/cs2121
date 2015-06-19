; Speaker Functions
keypress: 											; generates a 250ms beep - called when a keypress is successfully registered
	push temp1

	clr temp1 										; initialise keypress counter
	sts keypressCounter, temp1

	keypressloop:
		lds temp1, keypressCounter 					; loop 124 times
		inc temp1
		sts keypressCounter, temp1
		cpi temp1, 124
		breq keypressEpilogue

		sbi PORTB, 0  								; make sound
		rcall sleep_1ms
		cbi PORTB, 0
		rcall sleep_1ms
		rjmp keypressloop

	keypressEpilogue:
	pop temp1
	ret

initialiseFinishedSounds:
	push temp1

	; set up timer1 to interrupt every second
	; compare match value * 1024 prescale / 16 000 000 = 2 seconds
	; compare match value = 16 000 000 * 1 / 1024 = 31250
	; for 1 second, use 15,625 + buffer for any operations
	ldi temp1, (1 << WGM12)|(1 << CS12)|(1 << CS10) ; set prescale to 1024 and clear on compare match mode
	sts TCCR1B, temp1
	ldi temp1, high(16200)
	sts OCR1AH, temp1
	ldi temp1, low(16200)
	sts OCR1AL, temp1
	
	pop temp1
	ret

finishedSounds: 									; generates 3 1s beeps, with 1s of silence between each beep
	push temp1

	clr temp1
	sts finishedSoundCounter, temp1					; finishedSoundCounter = 0
	sts finishedBeepCounter, temp1 					; finishedBeepCounter = 0
	sts finishedBeepCounter + 1, temp1

	ldi temp1, (1 << OCIE1A) 						; enable interrupt on compare match in Timer 1
	sts TIMSK1, temp1

	finishedSoundsEpilogue:
	pop temp1
	ret

.equ HASHCOL = 2
.equ HASHROW = 3
.equ HASHCOLMASK = 0b10111111
.equ HASHROWOUTPUT = 0b00000111

checkHash:
	push temp1

	ldi cmask, HASHCOLMASK							; hash column mask (1011 1111)
	sts PORTL, cmask								; scan column 2

	ldi temp1, 0xFF									; slow down the scan operation to debounce button press
	checkHashDelay:
	dec temp1
	brne checkHashDelay

	lds temp1, PINL									; read PORTL
	andi temp1, ROWMASK								; get the keypad output value
	cpi temp1, HASHROWOUTPUT 						; check if row 3 is low
	brne checkHashEpilogue

	rcall clearFinishedText							; clear finished text from lcd
	ldi temp1, ENTRY 								; if current mode is FINISHED, set to ENTRY
	sts mode, temp1

	checkHashEpilogue:
	pop temp1
	ret