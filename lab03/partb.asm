; Part B: Moving Pattern
; Use LEDs and timer0 to display a moving pattern that rotates downwards on the green LEDs.
; Use timer0 to generate an interrupt that determines when LEDs are updated.
; Use a 16-bit pattern stored in a .equ constant.
; The pattern should shift by 1 bit every second. Display 8 bits at a time.
; Repeat the pattern every 16 seconds.

.include "m2560def.inc"

.equ PATTERN = 0b1010101011110000 ; 0x AA F0
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

.dseg
.org 0x200
SecondCounter:					; 2-byte counter used for counting seconds
	.byte 2
TempCounter:					; 2-byte temporary counter used to determine if 1 second has passed
	.byte 2
CurrentPattern:					; stores the current pattern that is displayed on the LEDs
	.byte 2

.cseg
.org 0x0000
	jmp RESET
	jmp DEFAULT					; IRQ0 not handled
	jmp DEFAULT					; IRQ1 not handled
.org OVF0addr
	jmp Timer0OVF				; jump to interrupt handler for Timer0 overflow
.org 0x0072
DEFAULT:
	reti						; used for interrupts that are not handled

RESET:
	ldi temp, high(RAMEND)		; initialise stack pointer
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp

	ser temp 					; set Port C as output
	out DDRC, temp

	rjmp main

Timer0OVF:						; interrupt subroutine to Timer0
	in temp, SREG
	push temp 					; save conflict registers
	push YH
	push YL
	push r25
	push r24
	push leds

	lds r24, TempCounter 		; load value of temporary counter
	lds r25, TempCounter + 1
	adiw r25:r24, 1 			; increase temporary counter by 1

	cpi r24, low(7812)			; compare temporary counter with 7812 = 10^6/128
	ldi temp, high(7812)
	cpc r25, temp
	brne notSecond 				; if they're not equal, jump to notSecond

	lds r24, CurrentPattern 	; otherwise we know that 1 second has expired
	lsr r24						; update CurrentPattern by right shifting it (MSB is at top of LEDs)
	sts CurrentPattern, r24
	lds r24, CurrentPattern + 1 ; load CurrentPattern + 1 and rotate right
	ror r24
	sts CurrentPattern + 1, r24
	brcc nocarry 				; jump to load pattern into LEDs
	lds r24, CurrentPattern
	set 						; T = 1
	bld r24, 7					; set last bit of CurrentPattern if c = 1
	sts CurrentPattern, r24 	; store into CurrentPattern
	nocarry:
	lds leds, CurrentPattern
	out PORTC, leds

	clear TempCounter			; reset temporary counter
	lds r24, SecondCounter 		; load second counter and increase since 1 second has expired
	lds r25, SecondCounter + 1
	adiw r25:r24, 1 			; increase second counter by 1

	sts SecondCounter, r24
	sts SecondCounter + 1, r25
	rjmp epilogue

notSecond:
	sts TempCounter, r24		; store new value of temporary counter
	sts TempCounter + 1, r25

epilogue:
	pop leds 					; pop conflict registers
	pop r24
	pop r25
	pop YL
	pop YH
	pop temp
	out SREG, temp
	reti 						; return from interrupt

main:							; you start in main, then interrupt when timer expires
	ldi temp, low(PATTERN)		; load PATTERN into CurrentPattern
	sts CurrentPattern, temp
	ldi temp, high(PATTERN)
	sts CurrentPattern + 1, temp

	lds leds, CurrentPattern 	; load pattern into LEDs
	out PORTC, leds 			; send to PORTC

	clear TempCounter 			; initialise temporary counter to 0
	clear SecondCounter 		; initialise second counter to 0
	ldi temp, 0b00000010
	out TCCR0B, temp 			; set prescaler to 8 = 278 microseconds
	ldi temp, 1 << TOIE0 		; enable timer
	sts TIMSK0, temp
	sei 						; enable global interrupt

halt:
     rjmp halt
