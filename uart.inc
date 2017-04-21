init_uart:	lcall 	initsio			;init baudrategenerator (t3) op 9600 baud (pllcon wordt gebruikt)
		setb	es			;UART interupt on
		clr	uart_in_mode
		clr	transmit	
		mov	uart_in_counter,#0h	
		clr	p2.5
		setb	p2.6
		setb	p2.7
		clr	uart_flag
		clr	error
		mov	uart_response,#0h
		mov	uart_out_counter,#0h
		RET
		
		
;UART 

uart_int:	push	psw
		push	acc
		mov	a,R0
		push	acc
		cpl	p2.5
		
uart_rec:	jnb	RI, uart_trans2 	;Received?
		cpl	p2.2
		mov	R0,SBUF			;lees ontvangen character;	
		
		jb	uart_in_mode,uart_lees	;als in mode 1, lees ; mode 0: check op startcommando ':'
		cjne	R0,#':',uart_trans2	;als geen start => negeren
		mov	uart_in_counter,#0h
		setb	uart_in_mode
		ljmp	uart_trans

uart_trans2:	ljmp	uart_trans

uart_bpm2:	ljmp	uart_bpm

uart_error2:	ljmp	uart_error
		
uart_lees:	mov	a,uart_in_counter
		cjne	a,#0h,uart_lees1	;counter op 0 => in buf1
		mov	uart_in1,R0
		inc	uart_in_counter
		ljmp	uart_trans	
uart_lees1:	cjne	a,#1h,uart_lees2	;counter op 1 => in buf2
		mov	uart_in2,R0
		inc	uart_in_counter
		ljmp	uart_trans
uart_lees2:	cjne	R0,#CR,uart_error2	;CR => commando checken en uitvoeren
		setb	uart_flag
		clr	uart_in_mode

; <= COMMANDO's =>

uart_init:	cpl	p2.6
		mov	a,uart_in1
		cjne	a,#'G',uart_sync		;init
		mov	a,uart_in2
		cjne	a,#'H',uart_error2
		
		mov	a,bpm_h
		lcall	batrans
		mov	transmit_h,a
		mov	a,bpm_l
		anl	a,#11110000b
		rr	a
		rr	a
		rr	a
		rr	a
		lcall	batrans
		mov	transmit_m,a
		mov	a,bpm_l
		anl	a,#00001111b
		lcall	batrans
		mov	transmit_l,a
		ljmp	uart_bpm

uart_sync:	cpl	p2.0
		mov	a,uart_in1
		cjne	a,#'O',uart_error			;sync
		mov	a,uart_in2
		cjne	a,#'H',uart_error
		
		mov	a,bpm_oh_h
		lcall	batrans
		mov	transmit_h,a
		mov	a,bpm_oh_l
		anl	a,#11110000b
		rr	a
		rr	a
		rr	a
		rr	a
		lcall	batrans
		mov	transmit_m,a
		mov	a,bpm_oh_l
		anl	a,#00001111b
		lcall	batrans
		mov	transmit_l,a
		ljmp	uart_bpm


;r0 en r1 komen binnen, de rest gewoon uitschrijven
uart_bpm:	setb	transmit
		inc	uart_response
		mov	a,uart_response
		mov	r0,#'0'			;transmit_h
		subb	a,#1
		jz	error_trans
		mov	r0,#'1'			;transmit_m
		subb	a,#1
		jz	error_trans
		mov	r0,#'3'			;transmit_l
		subb	a,#1
		jz	error_trans
		mov	r0,#' '
		subb	a,#1
		jz	error_trans
		mov	r0,#'B'
		subb	a,#1
		jz	error_trans
		mov	r0,#'P'
		subb	a,#1
		jz	error_trans
		mov	r0,#'M'
		subb	a,#1
		jz	error_trans
		mov	r0,#CR
		clr	transmit
		mov	uart_response,#0h
		ljmp	error_trans	
		
;<= afhandelen eindstates receiving =>	
uart_error:	clr	p2.7
		setb	error

		inc	uart_out_counter
		mov	a,uart_out_counter
		mov	r0,#'e'
		subb	a,#1
		jz	error_trans
		mov	r0,#'r'
		subb	a,#1
		jz	error_trans
		mov	r0,#'r'
		subb	a,#1
		jz	error_trans
		mov	r0,#'o'
		subb	a,#1
		jz	error_trans
		mov	r0,#'r'
		subb	a,#1
		jz	error_trans
		mov	r0,#'!'
		mov	uart_out_counter,#0h
		clr	error

error_trans:	mov	SBUF,r0			;schrijf character;	
		sjmp	uart_ret
		
uart_trans:	jnb	TI, uart_ret			;End Transmission?
		jb	error,uart_error
		jb	transmit,uart_bpm

uart_ret:	pop	acc
		mov	R0,a
		pop	acc
		pop	psw
		clr	TI
		clr	RI
		reti