; Part C: Calculator
; Use keypad to enter decimal numbers.
; A: 8-bit addition, B: subtraction, *: reset accumulator
; Accumulator starts at 0.
; Top line of LCD should display accumulator.
; Second line should show current number.

.include "m2560def.inc"

; Delay Constants
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4 				; 4 cycles per iteration - setup/call-return overhead

; LCD Instructions
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.set LCD_DISP_ON = 0b00001110
.set LCD_DISP_OFF = 0b00001000
.set LCD_DISP_CLR = 0b00000001

.set LCD_FUNC_SET = 0b00111000 						; 2 lines, 5 by 7 characters
.set LCD_ENTR_SET = 0b00000110 						; increment, no display shift

.set LCD_HOME_LINE = 0b10000000 					; goes to 1st line (address 0)
.set LCD_SEC_LINE = 0b10101000 						; goes to 2nd line (address 40)

; LCD Macros
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_command_reg
	mov r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_reg
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

; Keypad
.def row = r17										; current row number
.def col = r18										; current column number
.def rmask = r19									; mask for current row during scan
.def cmask = r20									; mask for current column during scan

.equ PORTLDIR = 0xF0								; -> 1111 0000 PL7-4: output, PL3-0, input
.equ INITCOLMASK = 0xEF								; -> 1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01								; -> 0000 0001 scan from the top row
.equ ROWMASK  = 0x0F								; -> 0000 1111 for obtaining input from Port L (note that first 4 bits are output)

; Calculator
.def current = r0
;.def current_H = r1
.def accumulator = r2
;.def accumulator_H = r3
.def address = r4
.def addressc = r5

; General
.def param = r16
.def temp1 = r21
.def temp2 = r22

.dseg
digits: .byte 4
currPress: .byte 1
wasPress: .byte 1

.cseg
; Vector Table
.org 0
	jmp RESET


RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser r16 										; set PORTF and PORTA to output
	out DDRF, r16
	out DDRA, r16
	clr r16											; clear PORTF and PORTA registers
	out PORTF, r16
	out PORTA, r16

	ldi temp1, PORTLDIR								; set PL7:4 to output and PL3:0 to input
	sts DDRL, temp1

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

	do_lcd_data '0' 								; initialise variables
	clr accumulator
	clr current
	ldi temp1, 128
	mov address, temp1
	ldi temp1, 168
	mov addressc, temp1
	clr temp1
	sts digits, temp1
	sts digits + 1, temp1
	sts digits + 2, temp1
	sts digits + 3, temp1
	sts currPress, temp1
	sts wasPress, temp1

	do_lcd_command LCD_SEC_LINE

main:
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
	sts PORTL, cmask								; otherwise, scan a column

	ldi temp1, 0xFF									; slow down the scan operation to debounce button press
	delay:
	dec temp1
	brne delay
	rcall sleep_20ms

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
	ldi temp1, 1 									; set currPress = 1
	sts currPress, temp1
	lds temp1, wasPress 							; if wasPress = 1, ignore keypad press
	cpi temp1, 1
	breq main

	cpi col, 3										; if the pressed key is in col.3 
	breq letters									; we have a letter
	cpi row, 3										; if the key is not in col 3 and is in row3,
	breq symbols									; we have a symbol or 0
	mov temp1, row 									; otherwise we have a number in 1-9
	lsl temp1 										; multiply temp1 by 2
	add temp1, row 									; add row again to temp1 -> temp1 = row * 3
	add temp1, col 									; temp1 = col*3 + row
	inc temp1

number:
	ldi temp2, 10
	mul current, temp2
	add current, temp1
	subi temp1, -'0'
	do_lcd_command_reg addressc
	do_lcd_data_reg temp1
	inc addressc
	jmp main										; restart main loop

letters:
	cpi row, 1
	breq subtraction 								; if row 1, B was pressed
	cpi row, 0
	breq addition 									; if row 1, B was pressed
	jmp main

symbols:
	cpi col, 0 										; if its in column 0, it's a star
	breq star
	cpi col, 1 										; if its in column 1, it's a zero
	breq zero
	jmp main

addition:
	add accumulator, current 						; A was pressed, so we need to perform addition
	clr current
	ldi temp1, 128
	mov address, temp1
	ldi temp1, 168
	mov addressc, temp1
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_HOME_LINE
	mov temp1, accumulator
	rcall write_digits
	do_lcd_command LCD_SEC_LINE
	jmp main

subtraction:
	sub accumulator, current
	clr current
	ldi temp1, 128
	mov address, temp1
	ldi temp1, 168
	mov addressc, temp1
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_HOME_LINE
	mov temp1, accumulator
	rcall write_digits
	do_lcd_command LCD_SEC_LINE
	jmp main

zero:
	ldi temp1, 0
	jmp number

star:
	clr accumulator 								; reset accumulator
	clr current
	ldi temp1, 128
	mov address, temp1
	ldi temp1, 168
	mov addressc, temp1
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_HOME_LINE
	do_lcd_data '0'
	do_lcd_command LCD_SEC_LINE
	jmp main

lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

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

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

sleep_20ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret

write_digits:
	push temp2

    ser temp2 										; check if initial number > 100 (3 digits)
    cpi temp1, 100
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

	write_digits_Epilogue:
	pop temp2
	ret