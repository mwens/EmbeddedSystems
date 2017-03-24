$NOLIST
$nomod51
$INCLUDE (c:/reg832.pdf)
$LIST



stack_init	equ	07fh			;beginadres programma
byte0		equ	0030h
byte1		equ	0031h
byte2		equ	0032h
byte3		equ	0033h
byte4		equ	0034h
byte5		equ	0035h
byte6		equ	0036h
byte7		equ	0037h
counter		equ	0038h			;gebruikte adressen: 0030h->0037h: shift register			
adc_value	equ	0039h			;			0038: timer interrupt
hr_grens	equ	0040h			;			0039: adc interrupt
mean		equ	0041h			;gemiddelde
bpm_h		equ	0042h
bpm_l		equ	0043h
grens_l		equ	0044h
grens_h		equ	0045h
bpm_val		equ	0046h
uart_in1	equ	0047h
uart_in2	equ	0048h
flank		bit	0
scr_refresh	bit	1
toggle_hartje	bit	2


		org	0000h
		sjmp	start
		org	000bh
		ljmp	timer0_int
		org	0023h
		ljmp	uart_int
		org	0033h
		ljmp	adc_int
		
start:		mov	pllcon,#0
		mov	sp,#stack_init		;stackpointer laten wijzen naar beginadres programma
		
		mov	tmod,#00100001b		;timer 1 in mode 2, timer 0 in mode 1 zetten.
		
		mov	adccon1,#10001000b	;MCLK Divider = 8
		mov	adccon2,#00000111b	;select channel 7
		
		setb	ea			;enable all Interrupt sources
		clr	eadc			;enable ADC interrupt
		mov	th0,#0D4h		;FA8A = -1398dec
		mov	tl0,#04Fh
		setb	et0			;enable timer0 interrupt
		setb	tr0
		
		clr	padc			;lage prioriteit voor adc
		setb	pt0			;hoge prioriteit voor timer0
		
		mov	counter,#0
		mov	adc_value,#0
		mov	hr_grens,#08Fh		;voorlopig grenswaarde
		
		clr	flank
		mov	mean,#0h
		
		lcall	initlcd
		mov	a,#0013h
		lcall	outcharlcd
		
		mov	dptr,#barchars		;balkje initieren
		lcall	build
		
		mov	a,#40
		mov	dptr,#eigenL
		lcall	build_adr
		
		clr	toggle_hartje
		
		
		setb	scr_refresh
		
		
		
		mov	scon,#01110000b		;mode1 uart 8 bits
		clr	et1
		mov	th1,#0F9h		;9709 BAUD is ongeveer 9600 Baud (1,14% error)
		mov	tl1,#0h
		;setb	smod
		setb	es			;uart interrupt enable
				

;main function

main:		jnb	scr_refresh,tweedeLijn
		clr	scr_refresh
		mov	a,#00ah				;Terug naar home positie (1,0)
		lcall	outcharlcd
		
		lcall	gemid				;calc gemiddelde (resultaat in mean)
		mov	r0,mean				
		lcall	bpm				;calc bpm waarde (resultaat in r0,input in r0)
		mov	bpm_val,r0
		lcall	hextodec
		mov	a,bpm_h
		lcall	outbytelcd
		mov	a,bpm_l
		lcall	outbytelcd
		
		
		lcall	balkje_jente	
		
		mov	a,#0013h
		lcall	outcharlcd

tweedeLijn:	mov	a,#00dh				;Terug naar home positie (0,0)
		lcall	outcharlcd
		mov	a,grens_h			;byte0
		lcall	outbytelcd
		mov	a,grens_l			;byte0
		lcall	outbytelcd

		mov	r0,hr_grens		
		lcall	balkje_matthias	



		mov	a,#08Eh				;positie opschuiven
		lcall	outcharlcd
		
		mov	a,#20h
		lcall	outcharlcd
		lcall	outcharlcd
		
		lcall	hextodec
		
		JNB	toggle_hartje,main
		

hartje:		mov	a,#08Eh				;positie opschuiven
		lcall	outcharlcd
		
		mov	a,#05h
		lcall	outcharlcd
		
		mov	a,#06h
		lcall	outcharlcd
		
		sjmp	main

;counter (FINAL)

;8ms = 101 0111 0110000 => 16.777216MHz / 12 = fclk timer 0 mode 0
;			1000micros/(1/fclk)
;11185 keer tellen voor 1ms
;3 onderste bit laten vallen van lsb_counter, shift, 3 bovenste worden msb_counter => timer 0 niet naar 8 ms, 

	
timer0_int: 	inc	counter			;TF0 wordt hardwarematig geset/reset
		mov	th0,#0D4h		;D44F = -11185dec
		mov	tl0,#04Fh
		
		push	acc
		push	psw
		jb	sconv,skipADC
		lcall	read_adc
		clr	c
		mov	a,hr_grens
		subb	a,adc_value
		jnc	flank_clr		;nog niet voorbij grenswaarde
		jb	flank,skipADC		;al eens voorbij geweest
		lcall	shift_8			;eerste keer voorbij
		setb	flank
		sjmp	skipADC
		
flank_clr:	clr	flank				
skipADC:	mov	a,counter
		CJNE	a,#00010111b,eindADC
		clr	toggle_hartje

eindADC:	pop	psw
		pop	acc
		mov	adccon2,#00000111b	;schakel naar kanaal 7, grenswaarden
		setb	eadc
		setb	sconv
		
		RETI
				
;Potentiometer inlezen

adc_int:	push	acc
		push	psw
		lcall	read_adc
		mov	hr_grens,adc_value
		mov	adccon2,#00000000b	;schakel naar kanaal 0, hartslagmeter (testkanaal 5)
		clr	eadc
		setb	sconv
		pop	psw
		pop	acc
		RETI



;READ INPUT ADC (FINAL)

shift_8:	push	acc
		mov	a,byte6
		mov	byte7,a
		mov	a,byte5
		mov	byte6,a
		mov	a,byte4
		mov	byte5,a
		mov	a,byte3
		mov	byte4,a
		mov	a,byte2
		mov	byte3,a
		mov	a,byte1
		mov	byte2,a
		mov	a,byte0
		mov	byte1,a
		mov	a,counter
		mov	byte0,a
		mov	counter,#0b
		setb	toggle_hartje
		pop	acc
		setb	scr_refresh
		RET

read_adc:	push	acc
		push	psw
		clr	adci
		mov	a,adcdatah
		anl	a,#00001111b	;onderste 4 bits bevatten 4 MSB van ADC
		rl	a		;laagste 4 bits op hoogste 4 posities
		rl	a
		rl	a
		rl	a
		mov	adc_value,a
		mov	a,adcdatal
		anl	a,#11110000b	;8 LSB van ADC => enkel 4 bovenste nodig
		rl	a		;hoogste 4 bits op laagste 4 posities
		rl	a
		rl	a
		rl	a
		orl	a,adc_value
		mov	adc_value,a		;overhouden 8 MSB van ADC input
		pop	psw
		pop	acc
		RET
		
; gemiddelde (of filter)

gemid:		push	acc
		push	psw
		mov	a,r1
		push	acc
		mov	a,r2
		push	acc
		mov	a,r3
		push	acc
		mov	a,r4
		push	acc
		mov	a,r5
		push	acc
		mov	a,r0
		push	acc

		mov	r1,#00h
		mov	r5,#00h
		mov	r0,byte0
		mov	r4,byte1
		lcall	add16
		mov	r4,byte2
		lcall	add16
		mov	r4,byte3
		lcall	add16
		mov	r4,byte4
		lcall	add16
		mov	r4,byte5
		lcall	add16
		mov	r4,byte6
		lcall	add16
		mov	r4,byte7
		lcall	add16
		mov	r4,#3h
		mov	r3,#0h
		mov	r2,#0h
		lcall	shiftright32
		mov	mean,r0		

		pop	acc
		mov	r0,a
		pop	acc
		mov	r5,a		
		pop	acc
		mov	r4,a
		pop	acc
		mov	r3,a
		pop	acc
		mov	r2,a
		pop	acc
		mov	r1,a
		pop	psw
		pop	acc
		RET
		
;omzetten naar hartslagen per minuut
; 7500/mean = bpm => a wordt omgewet en terug in a gestoken
		
bpm:		push	acc
		push	psw
		mov	a,r1
		push	acc
		mov	a,r4
		push	acc
		mov	a,r5
		push	acc
		
		mov	a,r0
		mov	r0,#04Ch		;1D4C = 7500
		mov	r1,#01Dh
		mov	r5,#0h
		mov	r4,a
		lcall	div16
		
		pop	acc
		mov	r5,a
		pop	acc
		mov	r4,a
		pop	acc
		mov	r1,a
		pop	psw
		pop	acc
		
		RET
	
			
;balkje gemiddelde
;r0 = value
balkje_jente:	push	acc
		push	psw
		mov	a,b
		push	acc
		
		mov	a,r0
		clr	c
		subb	a,#20
		mov	b,#5
		div	ab
		mov	b,a
		mov	r0,#40
		mov	a,#45h
		lcall	barlcd
		
		pop	acc
		mov	b,a
		pop	psw
		pop	acc
		RET
		
;balkje setwaarde
;r0 = value
balkje_matthias:push	acc
		push	psw
		mov	a,b
		push	acc
		
		mov	a,r0
		clr	c
		
		mov	b,#08h		;/6.4 = /64 * 10
		div	ab
		
		mov	b,#05h		;/6.4 = /64 * 10
		mul	ab
		
		mov	b,#04h		;/6.4 = /64 * 10
		div	ab
		
		mov	b,a
		
		mov	r0,#40
		mov	a,#05h
		lcall	barlcd
		
		pop	acc
		mov	b,a
		pop	psw
		pop	acc
		RET
		
;omzetten van hexadecimaal naar decimaal

hextodec:	push	acc
		push	psw
		mov	a,r0
		push	acc
		mov	a,r1
		push	acc
		mov	a,r2
		push	acc
		
		mov	r0,hr_grens
		mov	r1,#0h
		lcall	hexbcd16_u
		mov	grens_l,r0
		mov	grens_h,r1
		
		mov	r0,bpm_val
		mov	r1,#0h
		lcall	hexbcd16_u
		mov	bpm_l,r0
		mov	bpm_h,r1
		
		
		pop	acc
		mov	r2,a
		pop	acc
		mov	r1,a
		pop	acc
		mov	r0,a		
		pop	psw
		pop	acc	
		RET	
		
		
		
		
;UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART		
;UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART
;UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART
;UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART UART

uart_int:	reti
		
		
		
		
		
		
eigenL:		db	00001110b
		db	00011111b
		db	00011111b
		db	00011111b
		db	00001111b
		db	00000111b
		db	00000011b
		db	00000001b
		
eigenR:		db	00001110b
		db	00011111b
		db	00011111b
		db	00011111b
		db	00011110b
		db	00011100b
		db	00011000b
		db	10010000b
		
		
$INCLUDE (c:/aduc800_mideA.inc)		
end