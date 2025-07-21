remap
;input	a0	data (char set)
;	d0	size in words
;	d1	vram dest.
;	a1	mapping data (nibbles of color data)
	move	disflags,-(a7)
	bset	#dfng,disflags
	movem.l	a0-a2/d0-d4,-(a7)
	exg	d1,d0
	move.l	a0,a2
	bsr	vmaddr
	sub	#1,d1
.1	moveq	#3,d0
	move	(a2)+,d2
	clr	d3
.2	move	d2,d4
	and	#$f,d4
	or.b	0(a1,d4),d3
	ror	#4,d3
	ror	#4,d2
	dbf	d0,.2
	move	d3,(a0)
	dbf	d1,.1
	movem.l	(a7)+,a0-a2/d0-d4
	move	(a7)+,disflags
	rts

forceblack	;fade all colors to black but don't upset palfadenew
	movem.l	d0/a0,-(a7)
	move	#palfadenew,a0
	moveq	#31,d0
.0	move.l	(a0),-(a7)
	clr.l	(a0)+
	dbf	d0,.0
	move	#24,palcount
	bsr	forcefade
	moveq	#31,d0
.1	move.l	(a7)+,-(a0)
	dbf	d0,.1
.ex	movem.l	(a7)+,d0/a0
	rts

forcefade	;regardless of interupts/disflags fade in new palettes
	;don't upset anything else
	move	sr,-(a7)
	move.l	vbint,-(a7)
	move	disflags,-(a7)
	bclr	#dfng,disflags
	move.l	#Vb2,vbint.l
	move	#$2500,sr
.1	tst	palcount
	bpl	.1
	move	(a7)+,disflags
	move.l	(a7)+,vbint
	move	(a7)+,sr
	rts

cramfade	;fade from current color in color ram to color held in palfadenew
	;this should be called during vblank because palette changes punch holes in video
	tst	palcount
	bmi	rtss
	subq	#1,palcount
	bmi	rtss

	clr.l	d0
	move	palcount,d0
	cmp	#24,d0
	bgt	rtss
	divu	#3,d0
	swap	d0
	asl	#2,d0	;shifter 0/4/8
	moveq	#2,d3
	asl	d0,d3
	moveq	#$e,d5
	asl	d0,d5
	move	d5,d4
	not	d4
	move.l	#palfadenew,a1
	move.l	#Vdata,a0
	clr	d6
.top
	move	d3,d2

	move	d6,d0
	swap	d0
	move	#$20,d0
	move.l	d0,4(a0)
	move	(a0),d7        ;current color

	move	d7,d0
	and	d5,d0
	move	(a1)+,d1	;dest color
	and	d5,d1
	cmp	d1,d0
	beq	.next
	blt	.nn
	neg	d2
.nn	add	d2,d0
	and	d4,d7
	or	d0,d7

	move.l	#$c000,d0
	move.b	d6,d0
	swap	d0
	move.l	d0,4(a0)
	move	d7,(a0)

.next	addq	#2,d6
	cmp	#$80,d6
	bne	.top
	rts

;middle of code routines------------------------------------
randomd0s	;d0 = range
	;return d0 = random number (-range < d0 < range)
	move	d0,-(a7)
	asl	#1,d0
	bsr	randomd0
	sub	(a7)+,d0
	rts

randomd0	;d0 = range
	;return random number in d0 (0 <= d0 < range)
	movem.l	d0-d2,-(a7)
	move	seed+2,d0
	move	d0,d1
	move	seed,d2
	mulu	#$e62d,d0
	mulu	#$bb40,d1
	mulu	#$e62d,d2
	add	d2,d1
	swap	d0
	add	d1,d0
	swap	d0
	addq.l	#1,d0
	move.l	d0,seed
	asr.l	#8,d0
	mulu	2(a7),d0
	swap	d0
	addq	#4,a7
	movem.l	(a7)+,d1-d2
	rts

Sroot	;Square Root, this returns (d0.L)^.5 in d0
	tst.l	d0
	beq	rtss	;zero^.5 = zero
	;cmp.l	#40^2,d0
	cmpi.l  #(40*40),d0   ; Calculate multiplication
	bhi	.m2
	move.l	d1,-(a7)	;find square root of d0
	moveq	#-1,d1
.0	addq	#2,d1
	sub	d1,d0
	bcc	.0
	lsr	#1,d1
	move	d1,d0
	move.l	(a7)+,d1
	rts

.m2
	movem.l	d1-d3,-(a7)
	moveq	#9,d3	;max number of reps
	move	#$8000,d1
	cmp.l	#$00f00000,d0
	bhi	.top
	move.l	d0,d1
	lsr.l	#8,d1
	add	#2,d1
.top	move	d1,d2
	move.l	d0,d1
	divu	d2,d1
	add	d2,d1
	lsr	#1,d1
	cmp	d1,d2
	dbeq	d3,.top
	move	d1,d0
	movem.l	(a7)+,d1-d3
	rts

sfx	;play sound effect number
	;one word passed on stack
	movem.l	d0-d7/a0-a6,-(a7)
	clr.l	d0
	move	16*4(a7),d0
	bmi	.none
	move	d0,lastsfx
	jsr	p_initfx
.none
	movem.l	(a7)+,d0-d7/a0-a6
	move.l	(a7),2(a7)
	addq	#2,a7
	rts

song	;play song number
	;one word passed on stack
	movem.l	d0-d7/a0-a6,-(a7)
	clr.l	d0
	move	16*4(a7),d0
	bmi	.none
	jsr	p_initune
.none
	movem.l	(a7)+,d0-d7/a0-a6
	move.l	(a7),2(a7)
	addq	#2,a7
	rts

waitx	;wait d0 vblanks or until input from either joystick
	;return joystick variables (d0-d3) if any
	neg	d0
	move	d0,vcount
.wait
	bsr	ReadJoy1
	tst	d1
	bne	rtss
	bsr	ReadJoy2
	tst	d1
	bne	rtss
	move	vcount,d0
.0	cmp	vcount,d0
	beq	.0
	tst	d0
	bmi	.wait
	rts

waitxsr	;special version of waitx for zamboni crossing
	;wait d0 vblanks or until input from either joystick
	;return joystick variables (d0-d3) if any
	neg	d0
	move	d0,vcount
.wait
	tst	zamx
	bmi	.nz
	add	#1,zamx
.nz
	bsr	ReadJoy1
	tst	d1
	bne	rtss
	bsr	ReadJoy2
	tst	d1
	bne	rtss
	bsr	SetVideo
	move	vcount,d0
.0	cmp	vcount,d0
	beq	.0
	tst	d0
	bmi	.wait
	rts

waitxc1	;cycle palfade new colors for playoff screen hilite
	;return joystick variables (d0-d3) if any
.wait
	tst	palcount
	bpl	.noran
	movem.l	d1-d2/a0,-(a7)
	move.l	#palfadenew+$60,a0
	moveq	#0,d2
.pr0	add	#4,a0
	move	(a0),$1c(a0)
	moveq	#13,d1
.pr1	move	2(a0),(a0)+
	dbf	d1,.pr1
	dbf	d2,.pr0
	move	#8,palcount
	movem.l	(a7)+,d1-d2/a0
.noran
	move	vcount,d0
.0	cmp	vcount,d0
	beq	.0
	bra	OrJoy

waitjoy	;wait for either joystick input
	;return d1 = new button presses
	move	vcount,d0
.0	cmp	vcount,d0
	beq	.0
	bsr	orjoy
	beq	waitjoy
	rts

orjoy	;return d1 = new button presses
	bsr	ReadJoy1
	move	d1,-(a7)
	bsr	ReadJoy2
	or	(a7)+,d1
	rts

nodiag	;eliminate diagonal direction presses on d0
	movem.l	d0/d4-d5,-(a7)
	moveq	#3,d4
	move	d3,d0
	and	#$f,d0
	beq	.ok
.0	clr	d5
	bset	d4,d5
	cmp	d5,d0
	dbeq	d4,.0
	beq	.ok
	and	#$fff0,d1
.ok	movem.l	(a7)+,d0/d4-d5
	rts

ReadJoy1	;read controller 1
	;return d0 = direction (bit 0-3) and new button (bit 4-7) presses
	;d1 = new presses (all 8 bits)
	;d2 = changed buttons (all 8)
	;d3 = current held buttons (all 8)
	move.l	a0,-(a7)
	move.l	#Joy1,a0
	bsr	ReadJoy
	move.l	(a7)+,a0
	move	lj1,d2
	move	d1,lj1
	move	d1,d3
	eor	d1,d2
	and	d2,d1
	rts
ReadJoy2	;read controller 2
	;return d0 = direction (bit 0-3) and new button (bit 4-7) presses
	;d1 = new presses (all 8 bits)
	;d2 = changed buttons (all 8)
	;d3 = current held buttons (all 8)
	move.l	a0,-(a7)
	move.l	#Joy2,a0
	bsr	ReadJoy
	move.l	(a7)+,a0
	move	lj2,d2
	move	d1,lj2
	move	d1,d3
	eor	d1,d2
	and	d2,d1
	rts

ReadJoy	;read controller a0
	;return d0 = direction (bit 0-3) and new button (bit 4-7) presses
	;d1 = buttons down (all 8 bits)
	move	#$100,$a11100	;turn off z80
	move.b	#$40,6(a0)
	move.b	#$00,(a0)
	move	#$000,$a11100	;turn on z80
	move	#10,d1
.z	dbra	d1,.z
	move	#$100,$a11100	;turn off z80
	move.b	(a0),d0
	move.b	#$40,(a0)
	move	#$000,$a11100	;turn on z80

	asl.b	#2,d0
	and.b	#%11000000,d0
	move	#10,d1
.zz	dbra	d1,.zz
	move	#$100,$a11100	;turn off z80
	move.b	(a0),d1
	move	#$000,$a11100	;turn on z80
	and.b	#%00111111,d1
	or.b	d1,d0
	not.b	d0
	clr	d1
	move.b	d0,d1
	move	d1,-(a7)
	and	#$f0,d0
	and	#$0f,d1
	move.l	#jdtab,a0
	move.b	0(a0,d1),d1
	or	d1,d0
	move	(a7)+,d1
	rts

	;convert buttons l,r,d,u into direcitons 0-7,8
jdtab	dc.b	8,0,4,8,6,7,5,8,2,1,3,8,8,8,8,8

DoDMApro	;initiate dma transfer and protect from vblank interuption
	;d0 = words to transfer
	;d1 = initial vram address
	;a0 = address to transfer from
	move	disflags,-(a7)
	bset	#dfng,disflags
	bsr	DoDMA
	move	(a7)+,disflags
	rts	

DoDMA	;initiate dma transfer (dma transfer bug is compensated for)
	;d0 = words to transfer
	;d1 = destination vram address
	;a0 = source address
	movem.l	a1/d2,-(a7)
	move	d0,d2
	add	d2,d2
	add	a0,d2
	bcc	.nd
	beq	.nd
	lsr	#1,d2	;do two transfers if source address crosses 64k boundary
	sub	d2,d0
	move	d0,-(a7)
	bsr	.dd
	move	(a7)+,d0
	add	d0,d0
	add	d0,d1
	add	d0,a0
	move	d2,d0
	bra	.nd
.dd	movem.l	a1/d2,-(a7)
.nd
	lea	Vctrl,a1	;set d0-num of words
	move	#$8100+%01010100,(a1)
	move	#$8f02,(a1)	;    d1-Video address
	move	#$9300,d2	;    a0-Source address
	move.b	d0,d2
	move	d2,(a1)
	move	#$9400,d2
	lsr	#8,d0
	move.b	d0,d2
	move	d2,(a1)
	move.l	a0,d0
	lsr.l	#1,d0
	move	#$9500,d2
	move.b	d0,d2
	move	d2,(a1)
	lsr.l	#8,d0
	move	#$9600,d2
	move.b	d0,d2
	move	d2,(a1)
	lsr.l	#8,d0
	and.b	#$7f,d0
	move	#$9700,d2
	move.b	d0,d2
	move	d2,(a1)

	clr.l	d0
	move	d1,d0
	asl.l	#2,d0
	lsr	#2,d0
	or.l	#$00804000,d0

	move.l	d0,dmaram
	move	dmaram+2,(a1)
	move	dmaram,(a1)

	bsr	WaitDMA
	move	#$8100+%01100100,(a1)
	movem.l  (a7)+,a1/d2
	rts

DoFill	;fill vram
	;d0 = words to fill
	;d1 = vram address
	;d2 = data to fill with
	movem.l	a1/d3,-(a7)
	move.l	#Vdata,a1
	and.l	#$ffff,d1
	asl.l	#2,d1
	lsr	#2,d1
	or	#$4000,d1
	swap	d1
	move.l	d1,4(a1)
	move	d2,d3
	swap	d3
	move	d2,d3
	lsr	#1,d0
	subq	#1,d0
.0	move.l	d3,(a1)
	dbf	d0,.0
	movem.l	(a7)+,a1/d3
	rts

WaitDMA	;wait for dma completion
	move	Vctrl,-(a7)
	btst	#1,1(a7)
	addq	#2,a7
	bne	WaitDMA
	rts

setVram 	;initialize all necesary video parameters based on my variables
	;d0 = color to fade to
	move.l	#palfadenew,a0
	moveq	#63,d1
.0	move	d0,(a0)+
	dbf	d1,.0
	move	#24,palcount	
	bsr	forcefade
	

	move	disflags,-(a7)
	bset	#dfng,disflags
	VmInc	2	
	clr	d0
	bsr	Vmaddr
	move	#$3fff,d0
	clr.l	d1
.9	move.l	d1,(a0)
	dbf	d0,.9

	move	#$8c00,d0	;8 for shadow mode
	btst	#df32c,disflags
	bne	.i32
	or	#%10000001,d0
.i32	move	d0,4(a0)     ; 40 column mode, no interlace, normal brightness.

	move	#$8004,4(A0)	; 512 color palette enable
	move	#$8100+%01100100,4(a0)

	move	#$9001,d0	; Playfield is 64x32
	cmp	#6,Map1Col
	beq	.i64
	move	#$9003,d0
.i64	move	d0,4(a0)

	move	#$8200,d0
	move.b	VmMap1,d0
	lsr.b	#2,d0
	and.b	#%00111000,d0
	move	d0,4(a0)

	move	#$8400,d0
	move.b	VmMap2,d0
	lsr.b	#5,d0
	move	d0,4(a0)

	move	#$8300,d0
	move.b	VmMap3,d0
	lsr.b	#2,d0
	and.b	#%00111110,d0
	move	d0,4(a0)

	move	#$8500,d0
	move.b	VSPRITES,d0
	lsr.b	#1,d0
	move	d0,4(a0)

	move	#$8d00,d0
	move.b	VSCRLPM,d0
	lsr.b	#2,d0
	move	d0,4(a0)

	move	#$9100,4(a0)	;disable plane 3 graphics
	move	#$9200,4(a0)	;disable plane 3 graphics
	move.w	#$8700,4(a0)	; Palette # 0 is border/transparent.
	move.w	#$8B00,4(a0)	; Scroll mode.	(entire scroll)

	move.l	#$40000010,4(a0)	;vsram
	move.l	#$00000000,(a0)	;playfield 1/2
	move	(a7)+,disflags
	rts

Vmaddr	;set video port to address d0
	;d0 = vram address
	;returns a0 = Vdata!!!
	move.l	#Vdata,a0
	asl.l	#2,d0
	lsr	#2,d0
	or	#$4000,d0
	swap	d0
	and	#$0003,d0
	move.l	d0,4(a0)
	rts

dobitmap	;transfer palette data/map data/tiles data to vram
;a0 = palette
;a1 = map
;a2 = cat
;d0 = start x
;d1 = start y
;d2 = width x
;d3 = width y
;d4 = start char
;d5 = pal used bits (0-3) for color fam 1-4

	move	disflags,-(a7)
	bset	#dfng,disflags
	movem.l	d0-d5/a0-a3,-(a7)

	move.l	#palfadenew,a3
	bra	.00
.01	move.b	0(a0,d0),0(a3,d0)
	dbf	d0,.01
.02	add	#$20,a0
	add	#$20,a3
.00	moveq	#31,d0
	lsr	#1,d5
	bcs	.01
	bne	.02

	move	(a2)+,d0
	beq	.nochars
	move.l	a2,a0
	move	d4,d1
	asl	#4,d0	;data length
	asl	#5,d1	;start char
	bsr	DoDMA
.nochars
	move.l	a1,a2
	add	#4,a1
	move	printa,d5
	and	#$f800,d5
	move	14(a7),d2
	sub	#1,d2

.loop2	bsr	xyVmMap
	move	6(a7),d0	;y start
	mulu	(a2),d0	;map width
	add	2(a7),d0	;x start
	asl	#1,d0
	move	10(a7),d1
	sub	#1,d1
.loop1	move	0(a1,d0),d3
	add	d4,d3
	eor	d5,d3
	move	d3,(a0)
	add	#2,d0
	dbf	d1,.loop1
	add	#1,printy
	add	#1,6(a7)
	dbf	d2,.loop2
	movem.l	(a7)+,d0-d5/a0-a3
	move	(a7)+,disflags
	rts

xyVmMap	;use printx/y/m to set vram address
	;returns a0 = Vdata
	move	printx,d0
	move	printy,d1
	move	#VmMap1,a0
	add	printm,a0
	move.l	d2,-(a7)
	move	2(a0),d2
	asl	d2,d1
	move.l	(a7)+,d2
	add	d1,d0
	asl	#1,d0
	add	(a0),d0
	bra	Vmaddr

eraser	;fill rectangle with char
	;d0/d1 = x/y size of rectangle
	;d2 = char word to fill with
	;printx/y/m define top left corner to start at
	movem.l	d0-d2/a0,-(a7)
	move	disflags,-(a7)
	bset	#dfng,disflags
	movem	d0-d1,-(a7)
.1	bsr	xyVmMap
	move	(a7),d0
	sub	#1,d0
.0	move	d2,(a0)
	dbf	d0,.0
	add	#1,printy
	and	#31,printy
	sub	#1,2(a7)
	bne	.1
	add	#4,a7
	move	(a7)+,disflags
	movem.l	(a7)+,d0-d2/a0
	rts

Framer	;frame and fill (uses framer.map graphics and assums tiles are already located at framercset)
	;d0/d1 = x/y size of rectangle
	;printx/y/m define top left corner to start at
	movem.l	d0-d4/a0-a1,-(a7)
	move	disflags,-(a7)
	bset	#dfng,disflags
	movem	d0-d1,-(a7)
	move	printa,d2
	add	framercset,d2
	move.l	#framermap,a1
	add.l	4(a1),a1
	add	#4,a1
	clr	d4
	bsr	.tbline

	sub	#3,2(a7)
.mtop	bsr	.tbline
	sub	#6,d4
	sub	#1,2(a7)
	bpl	.mtop
	add	#6,d4
	bsr	.tbline
	add	#4,a7
	move	(a7)+,disflags
	movem.l	(a7)+,d0-d4/a0-a1
	rts

.tbline	bsr	xyVmMap
	add	#1,printy
	bsr	.setter
	add	#2,d4
	move	4(a7),d0
	sub	#3,d0
.tblp	bsr	.setter
	dbf	d0,.tblp
	add	#2,d4
	bsr	.setter
	add	#2,d4
	rts

.setter	move	(a1,d4),d3
	add	d2,d3
	move	d3,(a0)
	rts
	
printz	;see print
	;string macro should follow jsr to this routine
	move.l	(a7)+,a1
	bsr	print
	jmp	(a1)

print	;a1 = string macro
	;printx/y = x/y cordinate on map for printing
	;printm = map to print on
	;printa = attribute for characters

	;string	\-$ab,$xx,$yy,'Sample!'\
	;a = map number (1-3)
	;b = color/priority (0-3 = color fam, prio off),(4-7 = color fam, prio on)
	;xx = x cord to print at
	;yy = y cord to print at

	move	disflags,-(a7)
	bset	#dfng,disflags
	movem.l	d0-d3/a0/a2,-(a7)
	bsr	xyVmMap
	move	printa,d2
	move	(a1)+,d3
	sub	#2,d3
	bra	.1

.0	move.b	(a1)+,d0
	beq	.1
	ext	d0
	bpl	.nocom
	neg	d0
	move	d0,d2
	asl	#8,d2
	asl	#1,d2
	and	#$f800,d2
	move	d2,printa

	and	#3,d0
	asl	#2,d0
	sub	#4,d0
	move	d0,printm

	move.b	(a1)+,d0
	ext	d0
	move	d0,printx
	move.b	(a1)+,d1
	ext	d1
	move	d1,printy
	bsr	xyvmmap
	sub	#2,d3
	bra	.1

.nocom
	cmp.b	#'@',d0
	bne	.noblank
	moveq	#1,d0
	bra	.p
.noblank
	asl	#1,d0
	move.l	#smallfontmap,a2
	add.l	4(a2),a2
	move	4(a2,d0),d0
	add	smallfontchars,d0
.p	add	d2,d0			;for alternate paletes
	move	d0,(a0)
	add	#1,printx
.1	dbf	d3,.0
	movem.l	(a7)+,d0-d3/a0/a2
	move	(a7)+,disflags
	rts

PushTime	;convert d0 into string format of minutes:seconds
	;return a1 = string
	move	#mesarea+30,a1
	move.l	d0,-(a7)
	move.l	a1,-(a7)

	ext.l	d0
	divu	#10,d0
	swap	d0
	add	#'0',d0
	move.b	d0,-(a1)
	swap	d0

	ext.l	d0
	divu	#6,d0
	swap	d0
	add	#'0',d0
	move.b	d0,-(a1)
	swap	d0

	move.b	#':',-(a1)

	ext.l	d0
	divu	#10,d0
	swap	d0
	add	#'0',d0
	move.b	d0,-(a1)
	swap	d0

	tst	d0
	beq	.noz
	add	#'0',d0
	move.b	d0,-(a1)
.noz
	move.l	(a7)+,d0
	sub.l	a1,d0
	add	#2,d0
	btst	#0,d0
	beq	.1
	clr.b	-(a1)
	add	#1,d0
.1	move	d0,-(a1)
	move.l	(a7)+,d0
	rts	

PushNumber	;convert d0 into string format of base 10 number, no leading zeros
	;return a1 = string
	move	#mesarea+30,a1
	move.l	d0,-(a7)
	move.l	a1,-(a7)
.0	ext.l	d0
	divu	#10,d0
	swap	d0
	add	#'0',d0
	move.b	d0,-(a1)
	swap	d0
	tst	d0
	bne	.0
	move.l	(a7)+,d0
	sub.l	a1,d0
	add	#2,d0
	btst	#0,d0
	beq	.1
	clr.b	-(a1)
	add	#1,d0
.1	move	d0,-(a1)
	move.l	(a7)+,d0
	rts	

appendz	;see appstring
	;string macro should follow jsr to this routine
	move.l	(a7)+,a1
	bsr	appstring
	jmp	(a1)

appstring	;append string a1 to string a3
	movem.l	d0/a0,-(a7)
	lea	2(a3),a0
	move	(a3),d0
	sub	#3,d0
	bmi	.1
.0	add	#1,a0
	tst.b	(a0)
	dbeq	d0,.0
.1	move	(a1)+,d0
	sub	#3,d0
	bmi	.ex
.2	move.b	(a1)+,(a0)+
	bne	.3
	sub	#1,a0
.3	dbf	d0,.2
	move.l	a0,d0
	btst	#0,d0
	beq	.4
	clr.b	(a0)+
	add.l	#1,d0
.4	sub.l	a3,d0
	move	d0,(a3)
.ex	movem.l	(a7)+,a0/d0
	rts

printbigz	;see print big
	;string macro should follow jsr to this routine
	move.l	(a7)+,a1
	bsr	printbig
	jmp	(a1)

printbig	;same as print, only use bigfont.map graphics
	;a1 = string macro
	;printx/y = x/y cordinate on map for printing
	;printm = map to print on
	;printa = attribute for characters

	;string	\-$ab,$xx,$yy,'Sample!'\
	;a = map number (1-3)
	;b = color/priority (0-3 = color fam, prio off),(4-7 = color fam, prio on)
	;xx = x cord to print at
	;yy = y cord to print at

	move	disflags,-(a7)
	bset	#dfng,disflags
	movem.l	d0-d7/a0/a2,-(a7)
	move	printx,d4
	move	printy,d5
	move	printa,d6
	add	BigFontChars,d6

	move	(a1)+,d3
	sub	#2,d3
	bra	.1

.0	move.b	(a1)+,d0
	beq	.1
	ext	d0
	bpl	.nocom
	neg	d0
	move	d0,d6
	asl	#8,d6
	asl	#1,d6
	and	#$f800,d6
	move	d6,printa
	add	BigFontChars,d6

	and	#3,d0
	asl	#2,d0
	sub	#4,d0
	move	d0,printm

	move.b	(a1)+,d4
	ext	d4
	move	d4,printx
	move.b	(a1)+,d5
	ext	d5
	move	d5,printy
	sub	#2,d3
	bra	.1

.nocom	
	cmp.b	#'a', d0
	blt	.2
	cmp.b	#'z', d0
	bgt	.2
	add.b	#'A'-'a',d0
.2
	move	d3,-(a7)
	bsr	.dochar
	move	(a7)+,d3
.1	dbf	d3,.0
	move	d4,printx
	move	d5,printy
	movem.l	(a7)+,d0-d7/a0/a2
	move	(a7)+,disflags
	rts

.dochar
	sub	#$20,d0
	beq	.space
	move.l	#bfasciicon,a0
	moveq	#1,d2		;chars wide-1
	move.b	0(a0,d0),d1	;brush offset
	ext	d1
	bpl	.p0
	neg	d1
	clr	d2
.p0
	asl	#1,d1
	move.l	#bigfontmap,a0
	add.l	4(a0),a0
.p1
	move	4(a0,d1),d3
	bsr	.dump
	move	(a0),d7
	asl	#1,d7
	add	d7,d1
	move	4(a0,d1),d3
	sub	d7,d1
	addq	#1,d5
	bsr	.dump
	subq	#1,d5
	addq	#1,d4	;x char position
	addq	#2,d1
	dbf	d2,.p1
	rts
.dump
	add	d6,d3
.dump2
	movem.l	a0/d1,-(a7)
	move	d5,d0
	move.l	#VmMap1,a0
	add	printm,a0
	move	2(a0),d1
	asl	d1,d0
	add	d4,d0
	asl	#1,d0
	add	(a0),d0
	bsr	Vmaddr
	move	d3,(a0)
	movem.l	(a7)+,a0/d1
	rts
.space
	moveq	#1,d3	;blank char
	bsr	.dump2
	addq	#1,d5
	bsr	.dump2
	subq	#1,d5
	addq	#1,d4
	rts

bfasciicon	;equates to find each char definition for bigfont.map
	;	   -!  "  #  $  %  &  -'  (  )  *  +  ,  -  -.  /
	dc.b	00,-71,00,00,00,00,00,-70,00,00,00,00,00,00,-62,00
	;	 0   1  2  3  4  5  6  7  8  9   :  ;  <  =  >  ?
	dc.b	51,-53,54,56,58,60,62,64,66,68,-69,00,00,00,00,72
	;	@  A  B  C  D  E  F  G	H  -I  J  K  L  M  N  O
	dc.b	74,00,02,04,06,08,10,12,14,-16,17,19,21,23,25,27
	;	P  Q  R  S  T  U  V  W	X  Y  Z
	dc.b	29,31,33,35,37,39,41,43,45,47,49
	;
	IF REV=0 ; RETAIL
		dc.b $49
	ELSE ; REV A
		dc.b $FF
	ENDIF

	

Buildframelist
	;make a table in ram of each frames starting point
	;so as to have random acces to sprite graphics
	;a1 = animation file
	;a0 = start of ram table (1 long word/frame)

	;return a0 = tile set
	;a1 = palette data
	add	#2,a1
	move	(a1),d0	;number of frames
	add	#4,a1
.0	move.l	a1,(a0)+
	move	SprStrnum(a1),d1	;number of sprites in this frame
	asl	#3,d1
	add	#SprStrdat+8,d1
	add	d1,a1
	dbf	d0,.0

	move	2(a1),d0
	lea	2(a1),a0	;tile set

	ext.l	d0
	asl.l	#5,d0
	add.l	d0,a1	;palette
	add	#2,a1
	rts

AddSmallFont
	;transfer smallfont.map tiles to vram
	;d4 = char to start tiles at
	;return d4 = end of tiles + 1
	move.l	#smallfontmap,a0
	add	#8,a0
	move	d4,smallfontchars
	move	d4,d1
	move	(a0)+,d0
	add	d0,d4
	asl	#4,d0
	asl	#5,d1
	bra	DoDMA

AddFramer
	;transfer framer.map tiles to vram
	;d4 = char to start tiles at
	;return d4 = end of tiles + 1
	move.l	#Framermap,a0
	add	#8,a0
	move	d4,Framercset
	move	d4,d1
	move	(a0)+,d0
	add	d0,d4
	asl	#4,d0
	asl	#5,d1
	bra	DoDMA

AddTeamBlock
	;transfer TeamBlocks.map tiles to vram
	;d4 = char to start tiles at
	;return d4 = end of tiles + 1
	moveq	#2,d4
	move.l	#TeamBlocksmap,a0
	add	#8,a0
	move	d4,d1
	move	(a0)+,d0
	add	d0,d4
	asl	#4,d0
	asl	#5,d1
	bra	DoDMA