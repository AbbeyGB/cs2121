# cs2121

> Microprocessors and Interfacing. Semester 1, 2015.

[Course website](http://www.cse.unsw.edu.au/~cs2121/).

### Tips
+ You can include functions and constants from a separate file using ``.include "myfile.asm"``. For an example, see the project. Use this to separate your functions in the labs from the code that uses those functions - this will allow you to reuse the functions more easily later on.
+ The [instruction set](http://www.cse.unsw.edu.au/~cs2121/AVR/AVR-Instruction-Set.pdf) is your bible. The [datasheet](http://www.cse.unsw.edu.au/~cs2121/AVR/ATmega2560datasheet.pdf) explains how to set up different interrupts.

### Labs
1. **Data Memory, Program Memory**
  1. Add two 16-bit integers using registers.
  2. Add two arrays of integers and store in data memory.
  3. Convert a string to uppercase.
  4. Find the index of a character in a string.
  5. Bubble sort an array of integers.
2. **Functions, Stacks**
  1. Load a string from program memory and reverse it into data memory.
  2. Find the length of the longest string in a linked list.
  3. Find the maximum and minimum signed integers in a linked list.
3. **LEDs, Buttons**
  1. Display a static pattern on a series of LEDs.
  2. Display a rotating 16-bit pattern on a series of LEDs. The pattern shifts downwards every second.
  3. Display a user-entered pattern on the LEDs for a specified amount of time. The pattern is entered using two push buttons. The user must be able to queue a pattern while the previous one is displaying.
  4. Allow at least 32 patterns to be queued. If more than 4 patterns are queued, display the current pattern at twice the normal speed. If both buttons are pressed simultaneously, empty the queue and stop displaying the current pattern.
4. **LCDs, Keypad**
  1. Display the binary value of numeric keypad buttons on a series of LEDs when the button is pressed.
  2. Display a message on an LCD.
  3. Create a calculator for 8-bit addition and subtraction.
  4. Extend the calculator to support 8-bit multiplication and division.
5. **PWM, Motor**
  1. Measure the speed of a motor's rotation in revolutions per second using an optointerrupter.
  2. Make an LED fade in and out using PWM.
  3. Control the speed of a motor using a feedback system.

### Project

**Microwave emulator.** Includes a user manual and design manual.

### Assignment
**Comparing the Instruction Set Architectures of AVR and ARM.** Points of Comparison: Memory Models, Registers, Instruction Set, Data Types.
