initialiseButtons:
	push temp1

	lds temp1, EICRA
	ori temp1, (2 << ISC00)							; set INT0 to trigger on falling edges
	ori temp1, (2 << ISC10) 						; set INT1 to trigger on falling edges
	sts EICRA, temp1

	in temp1, EIMSK
	ori temp1, (1 << INT0) 							; enable INT0
	ori temp1, (1 << INT1) 							; enable INT1
	out EIMSK, temp1

	pop temp1
	ret
