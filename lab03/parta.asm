; Part A: Static Pattern
; Use green LEDs to display 0xE5
; MSB displayed on top LED
; LED pins 2 to 9 should be driven by port C

.include "m2560def.inc"

.equ PATTERN = 0xE5           ; 0b 1110 0101
.def leds = r16
.def temp = r17

     rjmp start
start:
     ser temp                 ; set temp to 1111
     out DDRC, temp           ; set direction of pin to output

     ldi leds, PATTERN        ; load pattern
     out PORTC, leds          ; write pattern to LEDs

halt:
     rjmp halt