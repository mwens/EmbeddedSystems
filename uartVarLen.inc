; =============================
; | UART Send/Receive Library |
; =============================

; INIT UART MODULE & var values

init_uart:	lcall 	initsio			;init baudrategenerator (t3) op 9600 baud (pllcon wordt gebruikt)
		setb	es			;UART interupt on
		clr	uart_in_mode
		clr	transmit	
		mov	uart_in_counter,#0h	
		clr	uart_flag
		clr	error
		mov	uart_response,#0h
		mov	uart_out_counter,#0h
		RET
		
		

; <== Start Interrupt ==>
; Transparantie: PSW, A en R0 mogen intern worden gebruikt
uart_int:	push	psw
		push	acc
		mov	a,R0
		push	acc

; <Start Receive> 		
		jnb	RI, uart_trans2 	;Received?
		mov	R0,SBUF			;lees ontvangen character;	
		
		; <Wachten op ':'>
		jb	uart_in_mode,uart_lees	;als in mode 1, lees ; mode 0: check op startcommando ':'
		cjne	R0,#':',uart_trans2	;als geen start => negeren
		mov	uart_in_counter,#0h
		setb	uart_in_mode
uart_trans2:	ljmp	uart_trans


		; <Commando inlezen (na ':')		
uart_lees:	mov	a,uart_in_counter
		cjne	a,#0h,uart_lees1	;counter op 0 => in buf1
		mov	uart_in1,R0
		inc	uart_in_counter
		ljmp	uart_trans	
uart_lees1:	cjne	a,#1h,uart_lees2	;counter op 1 => in buf2
		mov	uart_in2,R0
		inc	uart_in_counter
		ljmp	uart_trans
uart_lees2:	cjne	R0,#CR,uart_lees_error	;CR => commando checken en uitvoeren
		setb	uart_flag
		clr	uart_in_mode
		sjmp	uart_com_GH		; => VERDER GAAN NAAR COMMANDO SECTIE
uart_lees_error:mov	uart_in_counter, #0	; Reset UART In vlag/counter
		clr	uart_in_mode
		ljmp	uart_error_msg	

; <= COMMANDO's Uitvoeren =>
; COM 1: GH
uart_com_GH:	mov	a,uart_in1
		cjne	a,#'G',uart_com_OH	; Continue naar volgend COMMANDO		
		mov	a,uart_in2
		cjne	a,#'H',uart_error_tmp
		
		mov	a,bpm_h
		lcall	batrans			; omzettten naar ascii
		mov	transmit_bpm_h,a
		mov	a,bpm_l
		anl	a,#11110000b
		rr	a
		rr	a
		rr	a
		rr	a
		lcall	batrans
		mov	transmit_bpm_m,a
		mov	a,bpm_l
		anl	a,#00001111b
		lcall	batrans
		mov	transmit_bpm_l,a
		ljmp	uart_bpm
; COM 1: OH
uart_com_OH:	mov	a,uart_in1
		cjne	a,#'O',uart_error_tmp
		mov	a,uart_in2
		cjne	a,#'H',uart_error_tmp
		
		mov	a,bpm_oh_h
		lcall	batrans
		mov	transmit_bpm_h,a
		mov	a,bpm_oh_l
		anl	a,#11110000b
		rr	a
		rr	a
		rr	a
		rr	a
		lcall	batrans
		mov	transmit_bpm_m,a
		mov	a,bpm_oh_l
		anl	a,#00001111b
		lcall	batrans
		mov	transmit_bpm_l,a
		ljmp	uart_bpm
		
uart_error_tmp: ljmp	uart_error_msg


;r0 en r1 komen binnen, de rest gewoon uitschrijven
uart_bpm:	

		setb	transmit
		inc	uart_response
		mov	a,uart_response
		mov	r0,transmit_bpm_h			;transmit_h
		dec	a
		jz	uart_byte_trans
		mov	r0,transmit_bpm_m			;transmit_m
		dec	a
		jz	uart_byte_trans
		mov	r0,transmit_bpm_l			;transmit_l
		dec	a
		jz	uart_byte_trans
		mov	r0,#' '
		dec	a
		jz	uart_byte_trans
		mov	r0,#'B'
		dec	a
		jz	uart_byte_trans
		mov	r0,#'P'
		dec	a
		jz	uart_byte_trans
		mov	r0,#'M'
		dec	a
		jz	uart_byte_trans
		mov	r0,#CR
		clr	transmit
		mov	uart_response,#0h
		ljmp	uart_byte_trans	

uart_byte_trans:mov	SBUF,a				;schrijf character;
		sjmp	uart_ret		
		
		
; <Start Transmit>		
uart_trans:	jnb	TI, uart_ret			;SBUF fully transmitted?
		jb	error,uart_trans_msg
		jb	transmit,uart_bpm
		sjmp	uart_ret
				
		;<TRANSMIT MESSAGE FROM BUFFER> ('\0' ends sequence)
; INPUT: DPTR = startPos 	
uart_error_msg_OLD:	mov	dptr,#uart_input_error
		mov 	msg_pointer_l,#0h	; voorlopig gebruiken als counter voor XRAM
		
uart_cpy_loop:	mov	a,#0h
		movc	a,@a+dptr
		mov	msg_pointer_h,a		;voorlopig a opslaan
		
		mov	a,dph
		push	acc
		mov	a,dpl
		push 	acc
		
		mov	dph,#0h
		mov 	dpl,msg_pointer_l
		movx	@dptr,a
		inc 	msg_pointer_l
		
		pop	acc
		mov	dpl,a
		pop	acc
		mov	dph,a
		inc	dptr
		
		jnz	uart_cpy_loop
				
		mov 	msg_pointer_h,#0h
		mov 	msg_pointer_l,#0h
		sjmp	uart_trans_msg
; ff om te teste
uart_error_msg:	mov	dph,#0
		mov	dpl,#0
		mov	a,#'E'
		movx	@dptr,a
		inc 	dptr
		mov	a,#'!'
		movx	@dptr,a
		inc 	dptr
		mov	a,#0h
		movx	@dptr,a
		mov 	msg_pointer_h,#0h
		mov 	msg_pointer_l,#0h
		
uart_trans_msg: setb	error
		mov 	dph, msg_pointer_h	;laad counter in dptr
		mov 	dpl, msg_pointer_l
		movx	a,@dptr
		inc	dptr			;inc counter
		mov 	msg_pointer_h,dph	;sla counter op
		mov 	msg_pointer_l,dpl
		jz	einde
		mov	SBUF,a			;schrijf character;
		sjmp	uart_ret
		
einde:		clr	error
		sjmp	uart_ret


		

; <UART interrupt end>
uart_ret:	pop	acc
		mov	R0,a
		pop	acc
		pop	psw
		clr	TI
		clr	RI
		reti
		
; <== Einde Interrupt ==>

; <== VASTE STRINGS ==>
uart_input_error: 	db CR,CR,"--------------------------------------------------------------------------------",CR
			db "| ERROR! Type OH voor Ogenblikkelijke hartslag of GH voor Gemiddelde Hartslag! |"
			db CR,"--------------------------------------------------------------------------------",CR,CR,0
			
uart_bpm_text:		db "000 BPM",CR,0