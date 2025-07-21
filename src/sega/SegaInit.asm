;****************************************************************
;																*
;	GENESIS / MEGA DRIVE HARD INITIAL PROGRAM					*
;																*
;		1989 11/30												*
;																*
;	HOT_START is GAME_PROGRAM start_address						*
;		 = START + $100											*
;		because this program size is 256 bytes.					*
;																*
;       June 21'90                                              *
;****************************************************************
; No programs are permited to run before this program.

	org	$00000200
SegaInit:
	tst.l	$a10008		; POWER ON check cntroller A,B
	bne.s	h_s
	tst.w	$a1000c		; POWER ON check cntroller C
h_s:
	bne.s	hot_start

cold_start:
	lea.l	reg_set(pc),a5	; initial data address set
	movem.w	(a5)+,d5-d7		; regster initialize d5-d7.word
	movem.l	(a5)+,a0-a4		; regster initialize a0-a4.long

security:
	move.b	-$10ff(a1),d0	; ** a1 = $a11100 **
	andi.b	#$000f,d0		;  -$10ff(a1) = $a10000
	beq.s	japan		; Ver. No. check
	move.l	#'SEGA',$2f00(a1)	; "SEGA" moved to SECURITY part
japan:				; 2f00(a1) = $a14000
reg_init:
	move	(a4),d0		; vdp status dummy read
	moveq	#0,d0
	move.l	d0,a6
	dc.w	$4E66
;	move.l	a6,USP		; user stack pointer set
	moveq	#23,d1		; d1 = counter

;------<<< VDP REG. initialize >>>------
;    d5 = $8000 / d7 = $100
r_int1:
				; 
	move.b	(a5)+,d5		; vdp reg. 0-23 set
	move.w	d5,(a4)		;    (DMA fill set)
	add	d7,d5		; 
	dbra	d1,r_int1		; 
		
;------<<< DMA FILL >>>---------
dma_fill:				; already sat reg. #18,19,23
	move.l	(a5)+,(a4)
	move	d0,(a3)		; set fill data ($0) to $c00000

;-------<<< Z80 initialize >>>----
;	a0 = $a00000 / a1 = $a11100 / a2 = $a11200
; 	d0 = $0      / d7 = $100
z80_clr:
	move	d7,(a1)		; z80_busreq on
	move	d7,(a2)		; z80_reset off
z801:
	btst	d0,(a1)		; z80_bgack ok ?
	bne.s	z801

	moveq	#37,d2		; counter set
z802:
	move.b	(a5)+,(a0)+		; z80 program set to z80 sram
	dbra	d2,z802
	move	d0,(a2)		; z80_reset on
	move	d0,(a1)		; z80_busreq off
	move	d7,(a2)		; z80_reset off ( z80 start )
		
;--------<<< work ram clear >>>------------
; a6 = $0 / d0 = $0 / d6 = $3fff
clr_wk:
c_wk1:
	move.l	d0,-(a6)
	dbra	d6,c_wk1

;-------<<< VDP color clear >>>-------------
; a3 = $c00000 / a4 = $c00004 / d0 = $0
clr_col:
	move.l	(a5)+,(a4)		; vdp reg #1 = 4, #15 = 2
	move.l	(a5)+,(a4)
	moveq	#$1f,d3		; d3 = color ram size-1
c_col1:
	move.l	d0,(a3)
	dbra	d3,c_col1

; -------<<< V SCROLL clear >>>---------------
; a3 = $c00000 / a4 = $c00004 / d0 = $0
clr_vsc:
	move.l	(a5)+,(a4)
	moveq	#19,d4		; d4 = vscroll ram size-1
c_vsc1:
	move.l	d0,(a3)
	dbra	d4,c_vsc1

;---------<<< PSG clear >>>-------------------
; a3 = $c00000 / a4 = $c00004 / d0 = $0
; a5 = psg_dat (clear data) point
clr_psg:
	moveq	#3,d5		; counter set
c_psg1:
	move.b	(a5)+,$11(a3)
	dbra	d5,c_psg1
	
;-----------<<< regstars initial >>>------------
	move	d0,(a2)		; z80 reset
	movem.l	(a6),d0-d7/a0-a6	; initialize all registers
	move	#$2700,sr
hot_start:
	bra.s	CHECK_VDP

;*************************************************
;	tables
	
reg_set:					; registers set data table
	dc.w	$008000,$003fff,$000100		; d5 / d6 / d7
	dc.l	$a00000,$a11100,$a11200,$c00000	; a0 - a3
	dc.l	$c00004			; a4
vreg_dt:
	dc.b	$04,$14,$30,$3c,$07,$6c,$00,$00
	dc.b	$00,$00,$ff,$00,$81,$37,$00,$01
	dc.b	$01,$00,$00,$ff,$ff,$00,$00,$80
dma_fill_mode:
	dc.l	$40000080		; vdp_reg set data.dma_fill_mod
z80_reg:
	dc.b	$af		; xor	a
	dc.b	$01,$d9,$1f		; ld	bc,1fd9h
	dc.b	$11,$27,$00		; ld	de,0027h
	dc.b	$21,$26,$00		; ld	hl,0026h
	dc.b	$f9		; ld	sp,hl
	dc.b	$77		; ld	(hl),a
	dc.b	$ed,$b0		; ldir
	dc.b	$dd,$e1		; pop	ix
	dc.b	$fd,$e1		; pop	iy
	dc.b	$ed,$47		; ld	i,a
	dc.b	$ed,$4f		; ld	r,a
	dc.b	$d1		; pop	de
	dc.b	$e1		; pop	hl
	dc.b	$f1		; pop	af
	dc.b	$08		; ex	af,af'
	dc.b	$d9		; exx
	dc.b	$c1		; pop	bc
	dc.b	$d1		; pop	de
	dc.b	$e1		; pop	hl
	dc.b	$f1		; pop	af
	dc.b	$f9		; ld	sp,hl
	dc.b	$f3		; di
	dc.b	$ed,$56		; im1
	dc.b	$36,$e9		; ld	(hl),e9h
	dc.b	$e9		; jp (hl)
new_reg_data
	dc.l	$81048f02		; vdp reg#1=04,#15=02
clr_col_data
	dc.l	$c0000000		; color_ram address data
clr_vsc_data
	dc.l	$40000010		; v_scroll ram address data

psg_dat:
	dc.b	$9f,$bf,$df,$ff
	
	org	$2FA		;so that next instruction after tst is at $300
CHECK_VDP:				; this is protect to push
	tst	$c00004		; start_bottum rapid_firely.