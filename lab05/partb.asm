; Part B: LED Brightness
; Use Timer 3 and OC3B (PE4) in PWM mode.
; LED should fade from full brightness to completely off each second.
; Voltage supplied should decrease linearly.

; Note: ports labelled RX0, TX0, PE2, PE3 and PE5 work.
; Ports labelled PE4, PE6 and PE7 do not work.

.include "m2560def.inc"
.def temp = r16
.def brightness = r17

.cseg
.org 0x0000
	jmp RESET
.org 0x0072
DEFAULT:
	reti						; used for interrupts that are not handled

RESET:
	ldi temp, 0b00011000 		; set PE4 (OC3B) and PE5 (OC3C) to output
	out DDRE, temp

	ldi temp, 255 				; connected to PE5
	sts OCR3AL, temp
	clr temp
	sts OCR3AH, temp

	ldi temp, 255 				; connected to PE4 (externally labelled PE2)
	sts OCR3BL, temp
	clr temp
	sts OCR3BH, temp

	ldi brightness, 255

	ldi temp, (1 << CS30) 		; set the Timer3 to Phase Correct PWM mode. 
	sts TCCR3B, temp
	ldi temp, (1 << WGM31)|(1<< WGM30)|(1<<COM3B1)|(1<<COM3A1)
	sts TCCR3A, temp

duller:	
	dec brightness

	sts OCR3AL, brightness 		; connected to PE5
	sts OCR3BL, brightness 		; connected to PE2 (internally PE4)
	rcall sleep_4ms

	cpi brightness, 0 			; if brightness = 0 start increasing brightness
	brne duller

brighter:
	inc brightness

	sts OCR3AL, brightness 		; connected to PE5
	sts OCR3BL, brightness 		; connected to PE2 (internally PE4)
	rcall sleep_4ms

	cpi brightness, 255 		; if brightness = 255 start decreasing brightness
	brne brighter
	rjmp duller

; Delay Constants
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4 				; 4 cycles per iteration - setup/call-return overhead

; Delay Functions
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

sleep_4ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
