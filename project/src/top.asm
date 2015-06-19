; Turntable
.equ FRAMES = 4 									; 4 frames in turntable animation

; Motor
.equ INIT_RPS = 755 								; approximately 75 rps
.equ LEDS_POWER1 = 0b11111111 						; LED pattern for power level 1
.equ LEDS_POWER2 = 0b00001111 						; LED pattern for power level 2
.equ LEDS_POWER3 = 0b00000011 						; LED pattern for power level 3

; Keypad
.def row = r17										; current row number
.def col = r18										; current column number
.def rmask = r19									; mask for current row during scan
.def cmask = r20									; mask for current column during scan

.equ PORTLDIR = 0xF0								; -> 1111 0000 PL7-4: output, PL3-0, input
.equ INITCOLMASK = 0xEF								; -> 1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01								; -> 0000 0001 scan from the top row
.equ ROWMASK  = 0x0F								; -> 0000 1111 for obtaining input from Port L (note that first 4 bits are output)

; Modes
.equ ENTRY = 0
.equ RUNNING = 1
.equ PAUSED = 2
.equ POWER = 3
.equ FINISHED = 4

; Door
.equ DOOR_OPEN = 1
.equ DOOR_CLOSED = 0

; port h masks
.equ DOOR_LIGHT_MASK = 0b10111111

; LCD Instructions
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.set LCD_DISP_ON = 0b00001100 						; turn on display only
.set LCD_DISP_OFF = 0b00001000
.set LCD_DISP_CLR = 0b00000001

.set LCD_FUNC_SET = 0b00111000 						; 2 lines, 5 by 7 characters
.set LCD_ENTR_SET = 0b00000110 						; increment, no display shift

.set LCD_FIRST_LINE = 0b10000000 					; goes to 1st line (address 0)
.set LCD_COLON = 0b10000010 						; goes to location of timer colon (address 2)
.set LCD_START_TIME = 0b10000100 					; goes to smallest timer digit, where time is in mm:ss (address 4)
.set LCD_TURNTABLE = 0b10001111 					; goes to end of 1st line (address 15)
.set LCD_SEC_LINE = 0b10101000 						; goes to 2nd line (address 40)
.set LCD_DOOR_ICON = 0b10110111 					; goes to end of 2nd line (address 55)

; LCD Macros
.macro do_lcd_command 								; sends command to LCD from immediate operand
	ldi param, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_command_reg 							; sends command to LCD from register
	mov param, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data 									; prints data to LCD screen from immediate operand
	ldi param, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_reg 								; prints data to LCD screen from register
	mov param, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

; General
.def address = r2 									; used in write8 function
.def param = r16
.def temp1 = r21
.def temp2 = r22
.def temp3 = r23

; Jump Macros
.macro jeq
   brne pc+2
   rjmp @0
.endm

.macro jne
   breq pc+2
   rjmp @0
.endm

.macro jlo
   brsh pc+2
   rjmp @0
.endm

.macro jsh
   brlo pc+2
   rjmp @0
.endm

; Data Segment Variables
.dseg
.org 0x200
	mode: .byte 1 									; current mode
	door: .byte 1 									; state of the door

	minutes: .byte 1 								; remaining minutes to cook for
	seconds: .byte 1 								; remaining seconds to cook for
	numberEnteredDigits: .byte 1 					; number of digits entered in entry mode
	enteredDigits: .byte 4 							; digits entered in entry mode
	
	PowerValue: .byte 1 							; current power level

	; Keypad
	currPress: .byte 1 								; debouncing flag - is a keypad button currently pressed?
	wasPress: .byte 1 								; debouncing flag - was a keypad button pressed in the last scan?
	keypadNumber: .byte 1 							; number registered in keypad
	
	; LCD
	digits: .byte 4 								; used in write8 function

	; Turntable variables
	TurntableAnimation: .byte FRAMES				; stores turntable animation characters - / | \
	TurntableFrame: .byte 1							; stores the current frame in animation turntable is at (0-3)
	TurntableSeconds: .byte 1						; stores number of seconds since last frame change
	TempCounter: .byte 2 							; counts timer overflows
	TurntableDirection: .byte 1 					; if 0, turntable spins CCW; if 1 turntable spins CW

	; Motor variables
	rps: .byte 1

	; backlight variables
	BacklightCounter: .byte 2 						; counts timer overflows
	BacklightSeconds: .byte 1 						; counts number of seconds to trigger backlight fade out
	BacklightFadeCounter: .byte 1 					; used to pace the fade in/fade out process
	BacklightFade: .byte 1 							; flag indicating current backlight process - stable/fade in/fade out
	BacklightPWM: .byte 1 							; current backlight brightness

	; Speaker variables
	keypressCounter: .byte 1 						; number of loops so far
	finishedSoundCounter: .byte 1 					; number of beeps so far
	finishedBeepCounter: .byte 2 					; number of loops so far in a beep