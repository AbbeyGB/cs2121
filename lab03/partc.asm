; Part C: Dynamic Pattern
; Use 2 push buttons to enter a binary pattern, then display on LEDs.
; Left button (PB1) enters a 1, right button (PB0) enters a 0.
; When 8 bits have been collected, display on LEDs 3 times.
; Each flash should last 1 second. All LEDs should be turned off for 1 second after each flash.
; Bits should be displayed in the order they are entered. First one is on the top (MSB) LED.

; Use Timer0 to generate an interrupt to control the display speed.
; Use falling-edge external interrupts 0 and 1 to detect button pushes.
; It must be possible to enter a new pattern while the last one is still displaying.
; You can assume no more than one pattern will be entered while last one is displaying.

; Buttons must be software debounced, so 1 button reliably generates a single bit in the pattern.

.include "m2560def.inc"

.def leds = r16
.def temp = r17

; This macro clears a word (2 bytes) in memory.
; The parameter @0 is the memory address for that word
.macro clear
	ldi YL, low(@0)				; load memory address into Y
	ldi YH, high(@0)
	clr temp
	st Y+, temp					; clear two bytes at @0 in SRAM
	st Y, temp
.endmacro

.macro initialise_function
	push temp 						; save conflict registers
	push YH
	push YL
	push r25
	push r24
	push leds
	in temp, SREG 					; save status register
	push temp
.endmacro

.macro finalise_function
	pop temp 						; pop status register
	out SREG, temp 					
	pop leds 						; pop conflict registers
	pop r24
	pop r25
	pop YL
	pop YH
	pop temp
.endmacro

.dseg
.org 0x200
CurrentPattern:						; stores the current pattern that is displayed on the LEDs
	.byte 1
NextPattern: 						; stores next pattern
	.byte 1
BitsInPattern: 						; stores bits filled in NextPattern
	.byte 1
LeftButtonReady:					; used for debouncing
	.byte 1
RightButtonReady:					; used for debouncing
	.byte 1
Timer0OVFCounter: 					; counts overflows
	.byte 2
Timer0SECCounter: 					; counts seconds
	.byte 1
Timer1Counter: 						; used for debouncing
	.byte 1
Timer3Counter: 						; used for debouncing
	.byte 1

.cseg
.org 0x0000
	jmp RESET
	jmp RIGHT_BUTTON				; IRQ0 handled - connect PB0 to INT0 (RDX4) in Port D
	jmp LEFT_BUTTON					; IRQ1 handled - connect PB1 to INT1 (RDX3) in Port D
	jmp DEFAULT 					; IRQ2 Handler
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
	jmp DEFAULT 					; Timer/Counter2 Overflow
	jmp DEFAULT 					; Timer/Counter1 Capture Event
	jmp DEFAULT 					; Timer/Counter1 Compare Match A
	jmp DEFAULT 					; Timer/Counter1 Compare Match B
	jmp DEFAULT 					; Timer/Counter1 Compare Match C
	jmp TIMER1OVF 					; Timer/Counter1 Overflow
	jmp DEFAULT 					; Timer/Counter0 Compare Match A
	jmp DEFAULT 					; Timer/Counter0 Compare Match B
	jmp TIMER0OVF 					; Timer/Counter0 Overflow
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
	jmp TIMER3OVF 					; Timer/Counter3 Overflow
.org 0x0072
DEFAULT:
	reti							; used for interrupts that are not handled

RESET:
	ldi temp, high(RAMEND)			; initialise stack pointer
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp

	ser temp
	out DDRC, temp 					; set Port C as output
	clr temp
	out DDRD, temp 					; set Port D as input

	rjmp main

LEFT_BUTTON:
	initialise_function

	lds temp, LeftButtonReady		; if LeftButtonReady = 0 (not ready), go to epilogue
	cpi temp, 0
	breq LEFT_BUTTON_Epilogue

	ldi temp, 0 					; set LeftButtonReady to 0 (not ready)
	sts LeftButtonReady, temp		; this will be set back to 0xFF by Timer0

	ldi temp, 2 << CS00 			; overflow at 32768 (16-bit timer)
	sts TCCR1B, temp	 			; set prescaler to 8, overflow every 16384 microseconds
	ldi temp, 1 << TOIE1 			; enable Timer1
	sts TIMSK1, temp

	lds temp, BitsInPattern 		; if 8 bits in pattern, ignore most recent button press
	cpi temp, 8
	breq LEFT_BUTTON_Epilogue

	lds temp, NextPattern 			; left shift NextPattern, increment (to append a 1) and store
	lsl temp
	inc temp
	sts NextPattern, temp

	lds temp, BitsInPattern 		; increment BitsInPattern
	inc temp
	sts BitsInPattern, temp

	LEFT_BUTTON_Epilogue:
	finalise_function
	reti

RIGHT_BUTTON:
	initialise_function

	lds temp, RightButtonReady		; if RightButtonReady = 0 (not ready), go to epilogue
	cpi temp, 0
	breq RIGHT_BUTTON_Epilogue

	ldi temp, 0 					; set RightButtonReady to 0 (not ready)
	sts RightButtonReady, temp 		; this will be set back to 0xFF by Timer2

	ldi temp, 2 << CS00 			; overflow at 32768 (16-bit timer)
	sts TCCR3B, temp	 			; set prescaler to 8, overflow every 16384 microseconds
	ldi temp, 1 << TOIE3 			; enable Timer3
	sts TIMSK3, temp

	lds temp, BitsInPattern 		; if 8 bits in pattern, ignore most recent button press
	cpi temp, 8
	breq RIGHT_BUTTON_Epilogue

	lds temp, NextPattern 			; left shift NextPattern and store to append a 0 to the pattern
	lsl temp
	sts NextPattern, temp

	lds temp, BitsInPattern 		; increment BitsInPattern
	inc temp
	sts BitsInPattern, temp

	RIGHT_BUTTON_Epilogue:
	finalise_function
	reti

TIMER0OVF:
	initialise_function
	sei

	lds r24, Timer0OVFCounter 		; load value of overflow counter
	lds r25, Timer0OVFCounter + 1
	adiw r25:r24, 1 				; increase overflow counter by 1

	cpi r24, low(7812)				; compare overflow counter with 7812 = 10^6/128
	ldi temp, high(7812)
	cpc r25, temp
	brne notSecond 					; if they're not equal, jump to notSecond

	lds r24, Timer0SECCounter 		; otherwise we know that 1 second has expired
	clear Timer0OVFCounter			; reset Timer0OVFCounter

	cpi r24, 0 						; r24 contains Timer0SECCounter
	breq Timer0SECCounter0
	cpi r24, 1
	breq Timer0SECCounter135
	cpi r24, 2
	breq Timer0SECCounter2
	cpi r24, 3
	breq Timer0SECCounter135
	cpi r24, 4
	breq Timer0SECCounter4
	cpi r24, 5
	breq Timer0SECCounter135

	Timer0SECCounter0: 				; if Timer0SECCounter = 0
		lds temp, BitsInPattern 	; if Timer0SECCounter = 0 and BitsInPattern != 8, do nothing and go to epilogue
		cpi temp, 8
		brne WaitPattern

		lds temp, NextPattern 		; CurrentPattern = NextPattern
		sts CurrentPattern, temp
		ldi temp, 0 				; reset BitsInPattern
		sts BitsInPattern, temp
		lds leds, CurrentPattern
		out PORTC, leds 			; display pattern for 1s for the 1st time

		inc r24 					; increment Timer0SECCounter
		sts Timer0SECCounter, r24
		rjmp TIMER0OVF_Epilogue
	Timer0SECCounter135: 			; if Timer0SECCounter = 1/3/5
		clr leds 					; turn off LEDs for 1s
		out PORTC, leds

		inc r24 					; increment Timer0SECCounter
		sts Timer0SECCounter, r24
		rjmp TIMER0OVF_Epilogue
	Timer0SECCounter2: 				; if Timer0SECCounter = 2/4
		lds leds, CurrentPattern 	; display CurrentPattern for 1s for the 2nd
		out PORTC, leds

		inc r24 					; increment Timer0SECCounter
		sts Timer0SECCounter, r24
		rjmp TIMER0OVF_Epilogue
	Timer0SECCounter4: 				; if Timer0SECCounter = 4
		lds leds, CurrentPattern 	; display CurrentPattern
		out PORTC, leds
		clr temp 					; reset Timer0SECCounter to 0
		sts Timer0SECCounter, temp

		rjmp TIMER0OVF_Epilogue
	WaitPattern:
		clr leds
		out PORTC, leds

		rjmp TIMER0OVF_Epilogue

	notSecond:
		sts Timer0OVFCounter, r24	; store new value of overflow counter
		sts Timer0OVFCounter + 1, r25

	TIMER0OVF_Epilogue:
	finalise_function
	reti

TIMER1OVF:
	initialise_function

	lds temp, Timer1Counter
	inc temp
	sts Timer1Counter, temp
	cpi temp, 1 					; debounce at about 30 ms
	brne TIMER1OVF_Epilogue

	clr temp
	sts Timer1Counter, temp

	ldi temp, 0xFF
	sts LeftButtonReady, temp

	TIMER1OVF_Epilogue:
	finalise_function
	reti

TIMER3OVF:
	initialise_function

	lds temp, Timer3Counter
	inc temp
	sts Timer3Counter, temp
	cpi temp, 1 					; debounce at about 30ms
	brne TIMER3OVF_Epilogue

	clr temp
	sts Timer3Counter, temp

	ldi temp, 0xFF
	sts RightButtonReady, temp

	TIMER3OVF_Epilogue:
	finalise_function
	reti

main:							; you start in main, then interrupt when timer expires
	ser leds
	sts CurrentPattern, leds 	; load 0xFF into LEDs
	out PORTC, leds 			; send to PORTC

	ldi temp, 0xFF 				; initialise LeftButtonReady and RightButtonReady
	sts LeftButtonReady, temp 	; to 0xFF (ready)
	sts RightButtonReady, temp

	clear Timer0OVFCounter 		; initialise 2-byte variables to 0

	ldi temp, 0 				; initialise 1-byte variables to 0
	sts NextPattern, temp
	sts BitsInPattern, temp
	sts Timer0SECCounter, temp
	sts Timer1Counter, temp
	sts Timer3Counter, temp

	; External Interrupts
	ldi temp, (2 << ISC00)		; set INT0 to trigger on falling edges
	ori temp, (2 << ISC10) 		; set INT1 to trigger on falling edges
	sts EICRA, temp

	ldi temp, (1 << INT0) 		; enable INT0
	ori temp, (1 << INT1) 		; enable INT1
	out EIMSK, temp

	; Timer0
	ldi temp, (2 << CS00)
	out TCCR0B, temp 			; set prescaler to 8, overflow every 278 microseconds
	ldi temp, 1 << TOIE0 		; enable Timer0
	sts TIMSK0, temp

	sei 						; enable global interrupts

halt:
     rjmp halt
