$NOLIST
$nomod51
$INCLUDE (c:/reg832.pdf)
$LIST

;********************************************************************************************************************************
;*  ____ ____ ____ _______________ ____ ____ ____ ____ ____ ____ ____ ____ ____ 						*
;* ||T |||B |||P |||             |||P |||r |||e |||s |||e |||n |||t |||s |||: ||						*
;* ||__|||__|||__|||_____________|||__|||__|||__|||__|||__|||__|||__|||__|||__||						*
;* |/__\|/__\|/__\|/_____________\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|						*
;* 																*
;* .___________. __    __   _______    .______   .______   .___  ___. 								*
;* |           ||  |  |  | |   ____|   |   _  \  |   _  \  |   \/   | 								*
;*  ---|  |----`|  |__|  | |  |__      |  |_)  | |  |_)  | |  \  /  | 								*
;*     |  |     |   __   | |   __|     |   _  <  |   ___/  |  |\/|  | 								*
;*     |  |     |  |  |  | |  |____    |  |_)  | |  |      |  |  |  | 								*
;*     |__|     |__|  |__| |_______|   |______/  | _|      |__|  |__| 								*	
;*                                                                   								*
;* .______       ___________    ____  ______    __       __    __  .___________. __    ______   .__   __.      _______.		*
;* |   _  \     |   ____\   \  /   / /  __  \  |  |     |  |  |  | |           ||  |  /  __  \  |  \ |  |     /       |		*
;* |  |_)  |    |  |__   \   \/   / |  |  |  | |  |     |  |  |  | `---|  |----`|  | |  |  |  | |   \|  |    |   (----`		*
;* |      /     |   __|   \      /  |  |  |  | |  |     |  |  |  |     |  |     |  | |  |  |  | |  . `  |     \   \    		*
;* |  |\  \----.|  |____   \    /   |  `--'  | |  `----.|  `--'  |     |  |     |  | |  `--'  | |  |\   | .----)   |   		*
;* | _| `._____||_______|   \__/     \______/  |_______| \______/      |__|     |__|  \______/  |__| \__| |_______/    		*	
;********************************************************************************************************************************                                                                                                                   

; |=============================================================================================================================|
; |------------------------------------------------------ POWERED BY: ----------------------------------------------------------|
; |=============================================================================================================================|
; | |\/| _ _|__|_|_ . _  _  \    / _  _  _					 |  _  _ _|_ _   |_| _  _ _  _ _  _  _  _	|
; | |  |(_| |  | | ||(_|_\   \/\/ (/_| |_\ 			&		_| (/_| | | (/_  | |(/_| (/_| | |(_|| |_\     	|
; |=============================================================================================================================|




; |=====================================================|
; |----------------Memory map---------------------------|
; |=====================================================|

stack_init	equ	07fh			;beginadres programma
byte0		equ	0030h			;bytes voor gemiddelde (NIET IN BPM!)
byte1		equ	0031h
byte2		equ	0032h
byte3		equ	0033h
byte4		equ	0034h
byte5		equ	0035h
byte6		equ	0036h
byte7		equ	0037h
counter		equ	0038h			;counter voor timer
adc_value	equ	0039h
hr_grens	equ	0040h			;instelbaar door potentiometer => grenswaarde voor flankdetectie (formaat: hex)
mean		equ	0041h			;gemiddelde hartslag (hex)
bpm_h		equ	0042h			;hartslag in beats per minute (nibble per getal, decimaal) voor naar lcd
bpm_l		equ	0043h			
grens_l		equ	0044h			;instelbare grens (nibble per getal, decimaal) voor naar lcd
grens_h		equ	0045h
bpm_val		equ	0046h			;gemiddelde hartslag in bpm (hex)

uart_in1	equ	0047h			;uart buff in
uart_in2	equ	0048h						
uart_in_counter	equ	0049h			;uart buff current size
uart_out_counter equ	0050h			;uart out aantal reeds verzonden byte

transmit_bpm_h	equ	0052h			;ascii van gemiddelde/ogenblikkelijke hartslag vlak voor verzenden over uart (1 character/byte)
transmit_bpm_m	equ	0053h
transmit_bpm_l	equ	0054h
bpm_oh		equ	0055h			;hex van ogenblikkelijke hartslag (reeds in bpm)
bpm_oh_l	equ	0056h			;dec van ogenblikkelijke hartslag (reeds in bpm)
bpm_oh_h	equ	0057h			;dec van ogenblikkelijke hartslag (reeds in bpm)

msg_pointer_h	equ	0058h			;bijhouden dptr voor kopieren en verzenden van uart messages
msg_pointer_l	equ	0059h

flank		bit	0			;nieuwe hartslag
scr_refresh	bit	1			;screen refresh indien er nieuwe waarden zijn om weg te schrijven
toggle_hartje	bit	2			;hartje laten zien of niet.
uart_in_mode	bit	3			; ':' start commando => mode = 1 (CR eindigd,mode = 0).
sending_msg	bit	4			;vlag dat er gezonden wordt.
uart_flag	bit	5			;vlag dat een geldig commando ontvangen is.


; |=====================================================|
; |----------------Einde Memory map---------------------|
; |=====================================================|

; |=====================================================|
; |----------------Interrupt vectoren-------------------|
; |=====================================================|
		org	0000h
		sjmp	start
		org	000bh
		ljmp	timer0_int
		org	0023h
		ljmp	uart_int
		org	0033h
		ljmp	adc_int
		
; |=====================================================|
; |----------------Einde Interrupt vectoren-------------|
; |=====================================================|
		
; |=====================================================|
; |--------Initialisatie registers en variabelen--------|
; |=====================================================|		
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
		mov	a,#0013h		;zet cursor uit
		lcall	outcharlcd
		
		mov	dptr,#barchars		;balkje initieren
		lcall	build
		
		mov	a,#40
		mov	dptr,#eigenL		;hartje init
		lcall	build_adr
		
		clr	toggle_hartje
		
		
		setb	scr_refresh
		
		lcall	init_uart	
		
		mov	pwmcon,#10001100b	;PWM initieren
		mov	pwm0l,#08h
		mov	pwm0h,#0h
		mov	pwm1l,#11h
		mov	pwm1h,#0h
		orl	CFG832,#00000001b	;XRAMEN OP 1 ZETTEN! => XRAM aanzetten

; |=====================================================|
; |------Einde initialisatie registers en variabelen----|
; |=====================================================|

; |=====================================================|
; |--------------Main lus-------------------------------|
; |=====================================================|
main:		jnb	p2.7,clear			;errorpwm = p2.7 => alle andere ledjes volgen dit ledje
		orl	p2,#01111111b
		ljmp	vervolg
clear:		anl	p2,#10000000b

vervolg:	jnb	scr_refresh,tweedeLijn		;scr_refresh: is waarde aangepast? => scherm niet onnodig overschrijven
		clr	scr_refresh
		mov	a,#00ah				;Terug naar home positie (1,0)
		lcall	outcharlcd
		
		lcall	gemid				;calc gemiddelde (resultaat in mean)
		mov	r0,mean				
		lcall	bpm				;calc bpm waarde (resultaat in r0,input in r0)
		mov	bpm_val,r0
		mov	r0,byte0				
		lcall	bpm				;calc bpm waarde (resultaat in r0,input in r0)
		mov	bpm_oh,r0
		lcall	hextodec
		mov	a,bpm_h				;gemiddelde hartslag op scherm tonen
		lcall	outbytelcd
		mov	a,bpm_l
		lcall	outbytelcd
		
		mov	r0, bpm_val
		lcall	balkje_jente			;ogenblikkelijke hartslag grafisch tonen
		
		mov	a,#0013h
		lcall	outcharlcd

tweedeLijn:	mov	a,#00dh				;Terug naar home positie (0,0)
		lcall	outcharlcd
		mov	a,grens_h			;grenswaarde op scherm tonen
		lcall	outbytelcd
		mov	a,grens_l			
		lcall	outbytelcd

		mov	r0,hr_grens		
		lcall	balkje_matthias			;grenswaarde grafisch tonen



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

; |=====================================================|
; |--------------Einde Main lus-------------------------|
; |=====================================================|



; |=====================================================|
; |----------------TIMER 0 INTERRUPT--------------------|
; |=====================================================|
; | Elke 8 seconden word deze interrupt uitgevoerd	|
; | Aan 16.777216MHz : 8ms = 101 0111 0110000		|
; | Er word 11185 keer geteld voor 1ms			|
; | 3 onderste bits laten vallen van lsb_counter shift,	|
; | 3 bovenste worden msb_counter			|
; |		=> timer0 niet naar 8ms			|
; |=====================================================|	
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
	
; |=====================================================|
; |---------------EINDE TIMER 0 INTERRUPT---------------|
; |=====================================================|
			
; |=====================================================|
; |--------------------ADC INTERRUPT--------------------|
; |=====================================================|
; | Grenswaarde inlezen en daarna omschakelen naar	|
; | Hartslaglezen					|
; | Volledig transparant: enkel gedesigneerd RAM	| 
; |=====================================================|

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
; |=====================================================|
; |-----------------EINDE ADC INTERRUPT-----------------|
; |=====================================================|


; |=====================================================|
; |-----------------Shift Waardes-----------------------|
; |=====================================================|
; | Acht bytes worden bijgehouden voor gemiddelde waarde|
; | Shift deze 8 (verlies laatste byte)			|
; | Hartje word afgebeeld op scherm als aanduiding van	|
; | de ogenblikkelijke hartslag				|
; | Volledig transparant: enkel gedesigneerd RAM	| 		
; |=====================================================|
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
; |=====================================================|
; |-----------------Einde Shift waardes-----------------|
; |=====================================================|

; |=====================================================|
; |-----------------Read ADC waarde---------------------|
; |=====================================================|
; | De 4 LS-bits worden verwaarloosd			|
; | Volledig transparant: enkel gedesigneerd RAM	| 
; |=====================================================|
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
; |=====================================================|
; |-----------------Einde Read ADC waarde---------------|
; |=====================================================|

		
; |=====================================================|
; |-----------------Bereken gemiddelde hartslag---------|
; |=====================================================|
; | Berekent gemiddelde hartslag			|
; | Volledig transparant: enkel gedesigneerd RAM	| 
; |=====================================================|
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
; |=====================================================|
; |-----------------Einde bereken gemiddelde hartslag---|
; |=====================================================|

; |=====================================================|
; |-----------------Bereken BPM-------------------------|
; |=====================================================|
; | Maakt van de inhoud van R0 (tijdcounter) een BPM	|
; | Input:	R0	tijdswaarde hartslag		|
; | Output:	R0	bpm hartslag			|
; | Formule: 7500/mean = bpm				|
; |=====================================================|		
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
; |=====================================================|
; |-----------------Einde bereken BPM-------------------|
; |=====================================================|	
			

; |=====================================================|
; |-----------------Grafische balk gemiddelde BPM-------|
; |=====================================================|
; | Tekent een grafische voorstelling van de gem. BPM	|
; | op de 2e lijn van het LCD				|
; | Input: 	R0	waarde die word afgebeeld	|
; |=====================================================|
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
; |=====================================================|
; |-----------------Eind Grafische balk gemiddelde BPM--|
; |=====================================================|		


; |=====================================================|
; |-----------------Grafische balk grenswaarde BPM------|
; |=====================================================|
; | Tekent een grafische voorstelling van de grenswaarde|
; | op de 1e lijn van het LCD				|
; | Input: 	R0	waarde die word afgebeeld	|
; |=====================================================|
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
; |=====================================================|
; |-----------------Einde Grafische balk grenswaarde BPM|
; |=====================================================|	


; |=====================================================|
; |-------Converteer variabelen naar Decimaal-----------|
; |=====================================================|
; | Vormt verschillende waarden om naar decimale 	|
; | voorstelling. Elke nibble stelt 1 getal voor 	|
; | input: hr_grens, bmp_val & bpm_oh			|
; | output: grens_l, grens_h, bpm_l, bpm_h, bpm_oh_l &	|
; |  		bpm_oh_h				|
; |=====================================================|

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
		
		mov	r0,bpm_oh
		mov	r1,#0h
		lcall	hexbcd16_u
		mov	bpm_oh_l,r0
		mov	bpm_oh_h,r1
		
		
		pop	acc
		mov	r2,a
		pop	acc
		mov	r1,a
		pop	acc
		mov	r0,a		
		pop	psw
		pop	acc	
		RET	
; |=====================================================|
; |-----Einde Converteer variabelen naar Decimaal-------|
; |=====================================================|		
	
; |=====================================================|
; |-----Customn characters voor LCD (2-delig hartje)----|
; |=====================================================|	
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
		
$INCLUDE (uartVarLen.inc)		
$INCLUDE (c:/aduc800_mideA.inc)		
end
