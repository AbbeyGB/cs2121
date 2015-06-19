; Part A: Keypad
; Detect and debounce keypad presses.
; Buttons 0-9 should display their numeric value in binary, with the MSB at the top.
; Connect keypad to PORTL, with none of the wires crossed over.
; Low 4 bits connected to rows.
; High 4 bits used to read column output.

.include "m2560def.inc"
.def row = r16				; current row number
.def col = r17				; current column number
.def rmask = r18			; mask for current row during scan
.def cmask = r19			; mask for current column during scan
.def temp1 = r20
.def temp2 = r21
.equ PORTLDIR = 0xF0		; -> 1111 0000 PL7-4: output, PL3-0, input
.equ INITCOLMASK = 0xEF		; -> 1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01		; -> 0000 0001 scan from the top row
.equ ROWMASK  = 0x0F		; -> 0000 1111 for obtaining input from Port L (note that first 4 bits are output)

.cseg
.org 0x0000
	jmp RESET
	jmp DEFAULT						; IRQ0 Handler
	jmp DEFAULT						; IRQ1 Handler
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
	jmp DEFAULT 					; Timer/Counter1 Overflow
	jmp DEFAULT 					; Timer/Counter0 Compare Match A
	jmp DEFAULT 					; Timer/Counter0 Compare Match B
	jmp DEFAULT 					; Timer/Counter0 Overflow
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
	ldi temp1, low(RAMEND) 			; initialize the stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

	ldi temp1, PORTLDIR				; set PL7:4 to output and PL3:0 to input
	sts DDRL, temp1
	ser temp1						; PORTC is output
	out DDRC, temp1
	out PORTC, temp1 				; write 1s to PORTC

main:
	ldi cmask, INITCOLMASK	; initial column mask (1110 1111)
	clr col 				; initial column (0)

colloop:
	cpi col, 4 				; compare current column # to total # columns
	breq main				; if all keys are scanned, repeat
	sts PORTL, cmask		; otherwise, scan a column

	ldi temp1, 0xFF			; slow down the scan operation to debounce button press
	delay:
	dec temp1
	brne delay

	lds temp1, PINL			; read PORTL
	andi temp1, ROWMASK		; get the keypad output value
	cpi temp1, 0xF0 		; check if any row is low (0)
	breq rowloop			; if yes, find which row is low
	ldi rmask, INITROWMASK	; initialize rmask with 0000 0001 for row check
	clr row

rowloop:
	cpi row, 4 				; compare current value of row with total number of rows (4)
	breq nextcol			; if theyre equal, the row scan is over.
	mov temp2, temp1 		; temp1 is 0xF
	and temp2, rmask 		; check un-masked bit
	breq convert 			; if bit is clear, the key is pressed
	inc row 				; else move to the next row
	lsl rmask 				; shift row mask left by one
	jmp rowloop

nextcol:					; if row scan is over
	lsl cmask 				; shift column mask left by one
	inc col 				; increase column value
	jmp colloop				; go to the next column

convert:
	cpi col, 3				; if the pressed key is in col.3 
	breq main				; we have a letter, so ignore it and restart
	cpi row, 3				; if the key is not in col 3 and is in row3,
	breq symbols			; we have a symbol or 0
	mov temp1, row 			; otherwise we have a number in 1-9
	lsl temp1 				; multiply temp1 by 2
	add temp1, row 			; add row again to temp1 -> temp1 = row * 3
	add temp1, col 			; temp1 = col*3 + row
	subi temp1, -1			; add 1
	; 1 row 0 col 0 -> temp1 = 0 + 0 + 1 = 1 = 0b 0000 0001
	; 2 row 0 col 1 -> temp1 = 0 + 1 + 1 = 2 = 0b 0000 0010
	; 3 row 0 col 2 -> temp1 = 0 + 2 + 1 = 3 = 0b 0000 0011
	; 4 row 1 col 0 -> temp1 = 3 + 0 + 1 = 4 = 0b 0000 0100
	jmp convert_end

symbols:
	cpi col, 1 				; if its in column 1, it's a zero
	brne main 				; ignore * and #
	clr temp1
	jmp convert_end

convert_end:
	out PORTC, temp1		; write value to LEDs
	jmp main				; restart main loop
