	org	$00000100
;					Data	  	No.		Address	Description
	dc.b	'SEGA GENESIS    '	; 01	$100	Sega Genesis ID (16 bytes)
	dc.b	'(C)T-50 1991.MAY'	; 02	$110	company ID / release date (YYYY.MMM) (16 bytes)
	dc.b	'NHL HOCKEY      '	; 03	$120	game title for US market (32 bytes)
	dc.b	'                '	; 		$130
	dc.b	'                '	; 		$140
	dc.b	'NHL HOCKEY      '	; 04	$150	game title for Japanese market (32 bytes)
	dc.b	'                '	; 		$160
	dc.b	'                '	; 		$170
	dc.b	'GM T-50236 -00'	; 05	$180	cartridge cat., product no., version no. (14 bytes)
	IF CHECKSUM=1 ; Security check enabled
		IF REV=0 ; RETAIL
			dc.w	$93B8		; 06	$18E	check sum data (installed by checsum program) (2 bytes)
		ELSE ; REV A
			dc.w	$3E24 		; 06	$18E	check sum data (installed by checsum program) (2 bytes)
		ENDIF
	ELSE ; Security check disabled
		dc.w	$0000				; 06	$18E	check sum data (installed by checsum program) (2 bytes)
	ENDIF
	dc.b	'J               '	; 07	$190	I/O peripheral info. (J=Control Pad) (16 bytes)
	dc.l	$00000000,$0007FFFF	; 08	$1A0	cartridge size (start and end address) (16 bytes)
	dc.l	$00FF0000,$00FFFFFF	; 09	$1A8	RAM size (start and end address) (16 bytes)
	dc.b	'            '		; 10	$1B0	external RAM info. (12 bytes)
	dc.b	'            '		; 11	$1BC	modem info. (12 bytes)
	dc.b	'        '			; 12	$1C8	inhibit to use (40 bytes)
	dc.b	'                '	; 		$1D0
	dc.b	'                '	; 		$1E0
	dc.b	'U               '	; 13	$1F0	contry code for release (16 bytes)