; Minutes and seconds arithmetic
addSeconds: 										; adds value in temp1 to seconds variable
	push temp1
	push temp2

	addSecondsCheckOverflow:
		lds temp2, seconds
		add temp2, temp1
		cpi temp2, 99 								; if temp1 + seconds < 99, store the sum
		brlo addSecondsStore

	addSecondsSubtract: 							; if temp1 + seconds > 99
		lds temp2, minutes
		cpi temp2, 99
		brlo addSecondsMinutes
		ldi temp2, 99
		sts seconds, temp2
		jmp addSecondsEpilogue

		addSecondsMinutes:
			ldi temp2, 1 								; increment minutes
			rcall addMinutes
			lds temp2, seconds
			subi temp2, 60 								; seconds = seconds - 60
			sts seconds, temp2
			rjmp addSecondsCheckOverflow

	addSecondsStore:
		lds temp2, seconds 							; we know the sum is less than 99, so seconds = temp1 + seconds
		add temp2, temp1
		sts seconds, temp2

	addSecondsEpilogue:
	rcall dispMinutesSeconds						; display new time
	pop temp2
	pop temp1
	ret

subtractSeconds:								; subtracts value in temp1 from seconds
	push temp1
	push temp2
	
	lds temp2, seconds							; load seconds
	cp temp2, temp1								; check if seconds is greater than the value to subtract
	brlo subSecondsUF
	
	sub temp2, temp1							; subtract value from seconds
	rjmp subSecondsStore

	subSecondsUF:
		lds temp2, minutes						; load minutes
		cpi temp2, 0							; check minutes is greater than 0
		breq subSecondsZero						; if minutes = 0, set seconds to 0
		dec temp2								; decrement minutes
		sts minutes, temp2						; store minutes
		lds temp2, seconds						; load seconds
		sub temp1, temp2						; subtract leftover seconds from value
		cpi temp1, 61							; check if value is a minute or less
		brsh subSecondsUF						; if greater than a minute - repeat
		ldi temp2, 60							; set seconds to 60 - value
		sub temp2, temp1
		jmp subSecondsStore

	subSecondsZero:
		ldi temp2, 0

	subSecondsStore:
		sts seconds, temp2						; store seconds

	rcall dispMinutesSeconds					; display new time
	pop temp2
	pop temp1
	ret

addMinutes: 										; adds value in temp2 to minutes variable
	push temp1
	push temp2

	lds temp1, minutes
	add temp1, temp2
	cpi temp1, 99
	brlo addMinutesStore
	ldi temp1, 99 									; if minutes + temp2 > 99, minutes = 99
	addMinutesStore:
		sts minutes, temp1 							; otherwise minutes = minutes + temp2

	addMinutesEpilogue:
	rcall dispMinutesSeconds						; display new time
	pop temp2
	pop temp1
	ret
