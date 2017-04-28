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
		ljmp	uart_error		

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
		
uart_error_tmp: ljmp	uart_error


;r0 en r1 komen binnen, de rest gewoon uitschrijven
uart_bpm:	setb	transmit
		inc	uart_response
		mov	a,uart_response
		mov	r0,transmit_h			;transmit_h
		dec	a
		jz	uart_byte_trans
		mov	r0,transmit_m			;transmit_m
		dec	a
		jz	uart_byte_trans
		mov	r0,transmit_l			;transmit_l
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
		
		
		
; <Start Transmit>		
uart_trans:	jnb	TI, uart_ret			;SBUF fully transmitted?
		jb	error,uart_error
		jb	transmit,uart_bpm
		sjmp	uart_ret
				
		;<TRANSMIT MESSAGE FROM BUFFER> ('\0' ends sequence)
; INPUT: DPTR = startPos 	
uart_trans_msg:	setb	error
		inc	uart_out_counter
		mov	a,uart_out_counter
		
		mov	r0,#'e'
		dec	a
		jz	uart_byte_trans
		mov	r0,#'r'
		dec	a
		jz	uart_byte_trans
		mov	r0,#'r'
		dec	a
		jz	uart_byte_trans
		mov	r0,#'o'
		dec	a
		jz	uart_byte_trans
		mov	r0,#'r'
		dec	a
		jz	uart_byte_trans
		mov	r0,#'!'
		mov	uart_out_counter,#0h
		clr	error


uart_byte_trans:mov	SBUF,r0			;schrijf character;	
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
uart_input_error: 	db "ERROR!",CR,'\0'	