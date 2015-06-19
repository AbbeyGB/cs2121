; Part D: Enhanced Dynamic Pattern
; 1. Allow at least 32 patterns to be queued when they are entered faster than they
; 		can be displayed.
; 	- use ring buffer http://www.downtowndougbrown.com/2013/01/microcontrollers-interrupt-safe-ring-buffers/
; 2. If more than 4 patterns are queued, the current pattern should be displayed at
; 		twice the normal speed.
; 	- check if head = tail + 4
; 3. If both buttons are pressed simultaneously, queue should be emptied and current
; 		message should stop displaying immediately.

.include "m2560def.inc"

.equ RING_SIZE = 32
.equ DOUBLE_SPEED_THRESHOLD = 5
.equ DEBOUNCE_MULTIPLIER = 8

.def leds = r16
.def temp = r17
.def temp1 = r18
.def temp2 = r19

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
	push temp1
	push temp2
	push XH
	push XL
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
	pop XL
	pop XH
	pop temp2
	pop temp1
	pop temp
.endmacro

.dseg
.org 0x200
CurrentPattern:						; stores the current pattern that is displayed on the LEDs
	.byte 1
NextPatterns: 						; stores queued patterns as a ring buffer
	.byte RING_SIZE
Pattern_Bits: 						; stores bits filled in current byte location of Pattern_Head
	.byte 1
Pattern_Head: 						; stores the current byte location of the head of the buffer
	.byte 1 						; between 0 to RING_SIZE - 1
Pattern_Tail: 						; stores the current byte location of the tail of the buffer
	.byte 1 						; between 0 to RING_SIZE - 1
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
	ldi temp, (1<<INT0)|(0<<INT1)
	out EIMSK, temp

	lds temp, LeftButtonReady		; if LeftButtonReady = 0 (not ready), go to epilogue
	cpi temp, 0
	breq LEFT_BUTTON_Epilogue

	lds temp, RightButtonReady 		; if RightButtonReady = 0 (not ready), both buttons are pressed
	cpi temp, 0
	in temp1, SREG 					; load SREG into temp1
	sbrc temp1, SREG_Z 				; if SREG_Z = 1, then RightButtonReady = 0
	rjmp BOTH_BUTTONS 				; branch if RightButtonReady = 0

	ldi temp, 0 					; set LeftButtonReady to 0 (not ready)
	sts LeftButtonReady, temp		; this will be set back to 0xFF by Timer0

	ldi temp, 1 << TOIE1 			; enable Timer1
	sts TIMSK1, temp

	lds temp, Pattern_Head 			; if (Pattern_Head + 1) % RING_SIZE == Pattern_Tail, buffer is full
	inc temp
	andi temp, RING_SIZE - 1
	lds temp1, Pattern_Tail
	cp temp, temp1
	breq LEFT_BUTTON_Epilogue

	lds temp1, Pattern_Head
	ldi XL, low(NextPatterns) 		; X = &NextPatterns
	ldi XH, high(NextPatterns)
	add XL, temp1 					; X = &NextPatterns + Pattern_Head
	ldi temp, 0
	adc XH, temp
	ld temp, X 						; load NextPatterns + Pattern_Head into temp

	lsl temp 						; left shift pattern and append 1
	inc temp
	st X, temp

	lds temp, Pattern_Bits 			; increment Pattern_Bits
	inc temp
	sts Pattern_Bits, temp
	cpi temp, 8
	brne LEFT_BUTTON_Epilogue

	clr temp 						; if 8 bits in next pattern
	sts Pattern_Bits, temp			; clear Pattern_Bits
	lds temp, Pattern_Head			; Pattern_Head = (Pattern_Head + 1) % RING_SIZE
	inc temp
	andi temp, RING_SIZE - 1
	sts Pattern_Head, temp

	LEFT_BUTTON_Epilogue:
	ldi temp1, 0xFF			; slow down the scan operation to debounce button press
	delay:
	dec temp1
	brne delay

	finalise_function
	reti

RIGHT_BUTTON:
	initialise_function
	ldi temp, (0<<INT0)|(1<<INT1)
	out EIMSK, temp

	lds temp, RightButtonReady		; if RightButtonReady = 0 (not ready), go to epilogue
	cpi temp, 0
	breq RIGHT_BUTTON_Epilogue

	lds temp, LeftButtonReady 		; if LeftButtonReady = 0 (not ready), both buttons are pressed
	cpi temp, 0
	breq BOTH_BUTTONS

	ldi temp, 0 					; set RightButtonReady to 0 (not ready)
	sts RightButtonReady, temp 		; this will be set back to 0xFF by Timer2

	ldi temp, 1 << TOIE3 			; enable Timer3
	sts TIMSK3, temp

	lds temp, Pattern_Head 			; if (Pattern_Head + 1) % RING_SIZE == Pattern_Tail, buffer is full
	inc temp
	andi temp, RING_SIZE - 1
	lds temp1, Pattern_Tail
	cp temp, temp1
	breq RIGHT_BUTTON_Epilogue

	lds temp1, Pattern_Head
	ldi XL, low(NextPatterns) 		; X = &NextPatterns
	ldi XH, high(NextPatterns)
	add XL, temp1 					; X = &NextPatterns + Pattern_Head
	ldi temp, 0
	adc XH, temp
	ld temp, X 						; load NextPatterns + Pattern_Head into temp

	lsl temp 						; left shift pattern and append 1
	st X, temp

	lds temp, Pattern_Bits 			; increment Pattern_Bits
	inc temp
	sts Pattern_Bits, temp

	lds temp, Pattern_Bits
	cpi temp, 8
	brne RIGHT_BUTTON_Epilogue

	clr temp 						; if 8 bits in next pattern
	sts Pattern_Bits, temp			; clear Pattern_Bits
	lds temp, Pattern_Head			; Pattern_Head = (Pattern_Head + 1) % RING_SIZE
	inc temp
	andi temp, RING_SIZE - 1
	sts Pattern_Head, temp

	RIGHT_BUTTON_Epilogue:
	ldi temp1, 0xFF			; slow down the scan operation to debounce button press
	delay:
	dec temp1
	brne delay

	finalise_function
	reti

BOTH_BUTTONS:
	clr temp
	out EIMSK, temp

	clr leds 						; stop displaying current message
	out PORTC, leds

	clear Timer0OVFCounter
	clear Timer0SECCounter

	ldi temp, 0 					; empty queue
	sts Pattern_Bits, temp
	sts Pattern_Head, temp
	sts Pattern_Tail, temp

	ldi temp, 1 << TOIE1 			; enable Timer1
	sts TIMSK1, temp

	ldi temp, 1 << TOIE3 			; enable Timer3
	sts TIMSK3, temp

	BOTH_BUTTONS_Epilogue:
	finalise_function
	reti

TIMER0OVF:
	initialise_function
	sei

	lds r24, Timer0OVFCounter 		; load value of overflow counter
	lds r25, Timer0OVFCounter + 1
	lds temp, Pattern_Head 			; check if DOUBLE_SPEED_THRESHOLD+ patterns are queued
	lds temp1, Pattern_Tail
	ldi temp2, DOUBLE_SPEED_THRESHOLD
	add temp1, temp2
	cp temp, temp1 					; (Pattern_Head) - (Pattern_Tail + DOUBLE_SPEED_THRESHOLD)
	in temp2, SREG 					; if Pattern_Head >= Pattern_Tail then SREG_C = 0 and DOUBLE_SPEED_THRESHOLD+ patterns are queued
	sbrs temp2, SREG_C
	adiw r25:r24, 1 				; if DOUBLE_SPEED_THRESHOLD+ patterns are queued, overflow counter is increased by 2 instead of 1
	adiw r25:r24, 1 				; increase overflow counter by 1

	cpi r24, low(7812)				; compare overflow counter with 7812 = 10^6/128
	ldi temp, high(7812)
	cpc r25, temp
	brlo notSecond 					; if counter < 7812, jump to notSecond

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

	notSecond:
		sts Timer0OVFCounter, r24	; store new value of overflow counter
		sts Timer0OVFCounter + 1, r25
		rjmp TIMER0OVF_Epilogue

	Timer0SECCounter0: 				; if Timer0SECCounter = 0
		lds temp, Pattern_Head
		lds temp1, Pattern_Tail
		cp temp, temp1
		breq WaitPattern 			; if Pattern_Head == Pattern_Tail, buffer is empty so display nothing
		ldi XL, low(NextPatterns) 	; we know that Pattern_Head != Pattern_Tail, so we can get the next pattern
		ldi XH, high(NextPatterns)	; X = NextPatterns
		add XL, temp1 				; X = NextPatterns + Pattern_Tail
		ldi temp, 0
		adc XH, temp
		ld temp, X 					; load next pattern into temp
		sts CurrentPattern, temp 	; CurrentPattern = NextPatterns

		lds temp1, Pattern_Tail
        inc temp1 					; Pattern_Tail = (Pattern_Tail + 1) % RING_SIZE
        andi temp1, RING_SIZE - 1
        sts Pattern_Tail, temp1
		
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

	TIMER0OVF_Epilogue:
	finalise_function
	reti

TIMER1OVF:
	initialise_function

	lds temp, Timer1Counter
	inc temp
	sts Timer1Counter, temp
	cpi temp, DEBOUNCE_MULTIPLIER 	; debounce at DEBOUNCE_MULTIPLIER * 16 ms
	brne TIMER1OVF_Epilogue

	clr temp 						; clear Timer1Counter
	sts Timer1Counter, temp

	ldi temp, 0 << TOIE1 			; disable Timer1
	sts TIMSK1, temp

	ldi temp, 0xFF 					; set LeftButtonReady flag to 0xFF (ready)
	sts LeftButtonReady, temp

	in temp, EIMSK
	ori temp, (1<<INT1) 		; enable INT0 and INT1
	out EIMSK, temp

	TIMER1OVF_Epilogue:
	finalise_function
	reti

TIMER3OVF:
	initialise_function

	lds temp, Timer3Counter
	inc temp
	sts Timer3Counter, temp
	cpi temp, DEBOUNCE_MULTIPLIER 	; debounce at DEBOUNCE_MULTIPLIER * 16 ms
	brne TIMER3OVF_Epilogue

	clr temp 						; clear Timer3Counter
	sts Timer3Counter, temp

	ldi temp, 0 << TOIE3 			; disable Timer3
	sts TIMSK3, temp

	ldi temp, 0xFF 					; set RightButtonReady flag to 0xFF (ready)
	sts RightButtonReady, temp

	in temp, EIMSK
	ori temp, (1<<INT0) 		; enable INT0 and INT1
	out EIMSK, temp

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
	ldi temp1, 0
	sts Pattern_Bits, temp
	sts Pattern_Head, temp
	sts Pattern_Tail, temp
	sts Timer0SECCounter, temp
	sts Timer1Counter, temp
	sts Timer3Counter, temp

	; External Interrupts
	ldi temp, (2 << ISC00)		; set INT0 to trigger on falling edges
	ori temp, (2 << ISC10) 		; set INT1 to trigger on falling edges
	sts EICRA, temp

	ldi temp, (1<<INT0)|(1<<INT1) 		; enable INT0 and INT1
	out EIMSK, temp

	; Timer0
	ldi temp, (2 << CS00)
	out TCCR0B, temp 			; set prescaler to 8, overflow every 278 microseconds
	ldi temp, 1 << TOIE0 		; enable Timer0
	sts TIMSK0, temp

	; Timer1 (left button)
	ldi temp, 2 << CS00 		; overflow at 32768 (16-bit timer)
	sts TCCR1B, temp	 		; set prescaler to 8, overflow every 16384 microseconds

	; Timer3 (right button)	
	ldi temp, 2 << CS00 		; overflow at 32768 (16-bit timer)
	sts TCCR3B, temp	 		; set prescaler to 8, overflow every 16384 microseconds

	sei 						; enable global interrupts

halt:
     rjmp halt
