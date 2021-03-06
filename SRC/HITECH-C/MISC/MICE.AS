; MICE.AS: mouse, cursorkey and joystick functions for Hi-Tech C MSX.
;
; These functions perform direct I/O because speed is important for
; games.
; Games?! What games? I don't even have a joystick. So I have tested
; these with keyboard and mouse only. If the joystick routine doesn't
; work, send me a message: Pierre Gielen on MSXnet and FIDO's MSX.028,
; or pgn@dds.hacktic.nl on the Internet MSX mailing list.

; Assemble this file with Hi-Tech's ZAS.


; int mice()
; test mice: if 0 then none connected; if 1 then 1 mouse, port 1;
; if 2 then 1 mouse, port 2; if 3 then 2 mice, port 1 and 2;

	psect	text
	global	_mice

_mice:	xor	a			; A=0
	ld	(mickey),a		; save A
	ld	hl,1
	call	_chkmous		; port 1?
	ld	a,(mickey)
	jr	z,1f			; no mouse in port 1
	set	0,a			; A=1
1:	ld	(mickey),a		; save A
	ld	hl,2
	call	_chkmous		; port 2?
	ld	a,(mickey)
	jr	z,1f			; no mouse in port 2
	set	1,a			; A=2 if no mouse 1, else A=3
1:	ld	l,a
	ld	h,0			; result in hl
	ret
mickey: defb	0


; int chkmous(int p)
; test mouse in port p: returns 1 if connected, else 0. If no mouse
; is connected, the cursor will slowly move towards the lower right
; corner (X=1; Y=1).

	global	_chkmous

_chkmous:
	ld	a,l
	ld	hl,0			; return 0 as default
	or	a
	ret	z			; invalid portnumber
	cp	3
	ret	nc			; invalid portnumber
	ld	l,a
	call	_getmous		; test mouse
	ld	a,(xoffs)
	cp	1			; if 1
	jr	nz,1f			; mouse found
	ld	a,(yoffs)
	cp	1
	jr	nz,1f
	ld	hl,0			; no mouse (Z flag)
	ret
1:	ld	hl,1			; OK! (NZ flag)
	ret


; void getmouse(int p)
; reads the mouse in port p;  x-offset is returned as a signed char in
; 0xfafe, y-offset as a signed char in 0xfb00. Example of use:
; #define Xoffs (*(char *)0xfafe)
; #define Yoffs (*(char *)0xfb00)
; getmous(1);

	global	_getmous

	psgcontrol  equ 0a0h
	psgwrite    equ	0a1h
	psgread	    equ	0a2h

	xoffs	equ	0fafeh
	yoffs	equ	0fb00h

_getmous:
	ld	a,l			; get port number in A

	ld	e,00fh			; PSG register 15
	ld	bc,000bfh		; set bitmask B,C,H,L
	ld	hl,010efh		;   for mouse in port 1
	cp	1
	jr	z,gmous
	ld	bc,040ffh		; set bitmasks B,C,H,L
	ld	hl,020dfh		;   for mouse in port 2

gmous:	di
	call	realwe			; read PSG(15), AND L, write PSG(15)
	call	r15			; read PSG(15)
	push	af
	call	reohwe			; read PSG(15), OR H, write PSG(15)
	call	w3r15			; wait 3 ticks, read PSG(15)
	push	af
	call	realwe
	call	w1r15			; wait 1 tick, read PSG(15)
	push	af
	call	reohwe
	call	w1r15
	push	af
	call	realwe
	call	w1r15
	push	af
	call	reohwe
	call	w3r15
	push	af
	call	realwe
	call	sleep			; wait 1 tick
	call	reohwe
	call	sleep
	call	realwe
	ei				; interrupts on

	pop	af
	pop	hl
	pop	de
	pop	bc			; get masks and offsets
	xor	008h
	sub	002h
	cp	00dh
	jr	c,flofs
	pop	af
	call	mask
	ld	(yoffs),a
	pop	af
	call	mask
	jr	xsave
;
flofs:	ld	a,d
	add	a,a
	add	a,a
	add	a,a
	add	a,a
	or	h
	neg
	ld	(yoffs),a
	pop	af
	pop	de
	add	a,a
	add	a,a
	add	a,a
	add	a,a
	or	b
	neg
xsave:	ld	(xoffs),a
	ld	a,0ffh
	ret

mask:	xor	008h
	bit	3,a
	ret	z
	or	0f0h
	ret

realwe: call	rpsge			; read PSG register E
	and	l			; and L
	jr	wrpsg			; write PSG register E

reohwe: call	rpsge
	or	h
wrpsg:	push	af
	ld	a,e
	out	(psgcontrol),a
	pop	af
	out	(psgwrite),a
	ret
;
w3r15:	call	sleep			; read PSG with delay
	call	sleep
w1r15:	call	sleep
r15:	ld	a,00eh
	call	rdpsg
	and	00fh
	ret
;
rpsge:	ld	a,e			; read PSG register E
rdpsg:	out	(psgcontrol),a		; read PSG register A
	in	a,(psgread)
	and	c
	or	b
	ret
;
sleep:	ex	(sp),hl 		; delay (wait for slow mouse)
	ex	(sp),hl
	ex	(sp),hl
	ex	(sp),hl
	ret



; int stick(int p)
; get the direction value (0..8) of stick number p. See your BASIC
; manual (no kidding) for the instructions on how to use STICK(p).


	global	_stick

_stick:
	di
	ld	a,l
	or	a
	jr	z,st0		; stick(0)
	call	seljoy		; select stick(1) or stick(2)
	ld	a,14
	out	(psgcontrol),a	; read PSG register 14
	in	a,(psgread)
	and	00001111B	; r;l;d;u
	ld	hl,jtab 	; use joystick table
	jr	jfnd		; find position

st0:	ld	a,8		; row 8
	call	keyrow		; read keyboard
	rrca
	rrca
	rrca
	rrca
	and	00001111B	; r;d;u;l
	ld	hl,ktab 	; look for code in keytab
jfnd:
	ld	b,8
1:	cp	(hl)		; found?
	jr	z,3f
	inc	hl
	djnz	1b
	xor	a		; none, is 0
	jp	trdy
3:	ld	a,9
	sub	b
	jp	trdy		; interrupts on; result in HL; ret



; int trigger(int p)
; Get trigger status for stick p. Returns 0=no button, 1=button 1,
; 2=button 2, 3=button 1 & 2. On keyboard, the SHIFT key functions
; as button 2. On the mouse, left button= 1, right button= 2.

	global	_trigger

_trigger:
	di
	ld	a,l
	or	a
	jr	z,tr0		; trig(0)
	call	seljoy		; select trig(1) or trig(2)
	ld	a,14
	out	(psgcontrol),a	; read PSG register 14
	in	a,(psgread)
	rrca
	rrca
	rrca
	rrca
	cpl			; make sure 1 = active, 0=inactive
	and	00000011B	; button B, button A
	jr	trdy

tr0:	ld	a,8		; row 8
	call	keyrow
	cpl
	and	00000001B	; space bar
	ld	c,a
	ld	a,6		; row 6
	call	keyrow
	cpl
	rlca
	and	00000010B	; shift key
	or	c		; | space
trdy:	ei
	ld	l,a
	ld	h,0		; result in HL
	ret

; select joystick 1 or 2

seljoy:
	cp	2
	ld	a,15
	out	(psgcontrol),a	; read PSG register 15
	in	a,(psgread)
	jr	z,1f		; flags from 'cp 2'
	res	6,a		; stick(1)
	jr	2f
1:	set	6,a		; stick(2)
2:	ld	e,15
	call	wrpsg
	ret

; read keyrow specified in A

keyrow:
	ld	b,a
	in	a,(0aah)
	and	11110000B	; save click, CAPS and cas: bits
	or	b		; select row
	out	(0aah),a
	in	a,(0a9h)	; read keyboard
	ret


	psect	data

ktab:	defb	00001101B	; 1: up
	defb	00000101B	; 2: up&right
	defb	00000111B	; 3: right
	defb	00000011B	; 4: right&down
	defb	00001011B	; 5: down
	defb	00001010B	; 6: left&down
	defb	00001110B	; 7: left
	defb	00001100B	; 8: left&up
				; 0: else nothing

jtab:	defb	00001110B	; 1: up
	defb	00000110B	; 2: up&right
	defb	00000111B	; 3: right
	defb	00000101B	; 4: right&down
	defb	00001101B	; 5: down
	defb	00001001B	; 6: left&down
	defb	00001011B	; 7: left
	defb	00001010B	; 8: left&up
				; 0: else nothing

	end
                                                                                                              