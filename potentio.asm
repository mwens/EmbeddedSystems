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
flank		bit	0


		org	0000h
		sjmp	start
		org	000bh
		ljmp	timer0_int
		org	0033h
		ljmp	adc_int
		
start:		mov	pllcon,#0
		mov	sp,#stack_init		;stackpointer laten wijzen naar beginadres programma
		
		mov	tmod,#11110001b		;timer 1 laten staan zoals hij stond, timer 0 in mode 0 zetten.
		
		mov	adccon1,#10001000b	;MCLK Divider = 8
		mov	adccon2,#00000101b	;select channel 7
		
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

;main function

main:		mov	a,#0dh
		lcall	outcharlcd
		lcall	gemid
		mov	a,mean				;byte0
		lcall	bpm
		lcall	outbytelcd
		mov	a,#00ah
		lcall	outcharlcd
		mov	a,hr_grens			;byte0
		lcall	outbytelcd
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
skipADC:	pop	psw
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
		mov	adccon2,#00000101b	;schakel naar kanaal 0, hartslagmeter
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
		pop	acc
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
		RET
		
;omzetten naar hartslagen per minuut
; 7500/mean = bpm => a wordt omgewet en terug in a gestoken
		
bpm:		mov	r0,#04Ch		;1D4C = 7500
		mov	r1,#01Dh
		mov	r5,#0h
		mov	r4,a
		lcall	div16
		mov	a,r0			
		RET
		
		
$INCLUDE (c:/aduc800_mideA.inc)		
end
