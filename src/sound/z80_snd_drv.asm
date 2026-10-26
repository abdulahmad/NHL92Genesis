; =============================================================================
; NHL Hockey (NHL 92) Sega Genesis - Z80 sound driver
; =============================================================================
; Source for the Z80 program that Sound_LoadZ80Program (src/sound/sound.asm)
; copies into Z80 RAM at $0000 ($A00000 on the 68000 side). In the retail ROM
; these bytes sit at $116A6-$11C3D (Z80_Program_Code). Built with asm80
; (npm package, see README) into output/<mode>/obj/z80_snd_drv.bin, which
; sound.asm includes in place of the bytes that used to be extracted from the ROM.
;
; What the driver does
;   - Plays one 8-bit PCM sample at a time on the YM2612 DAC (channel 6),
;     reading it straight out of 68000 ROM through the Z80 bank window
;     ($8000-$FFFF). The 68000 requests a sample through the SFX mailbox at
;     $00BE-$00C3 (Sound_WriteYM2612 on the 68000 side).
;   - Between DAC bytes, when the 68000 has posted a new music/SFX update
;     (z80_audio_update_flag = 0), writes the six FM channel slots of
;     z80_channel_data_buffer to the YM2612: patch load, key on/off,
;     frequency, carrier total level.
;   - It never writes the PSG and never reads the YM2612 status register.
;     Timing between YM2612 writes is padded with push/pop pairs instead.
;
; Several instructions are patched at run time (self-modifying code): the
; DAC rate, the start bank and the start address of the sample live in the
; operands of instructions. Those operands have their own labels below
; (z80_dac_rate, z80_dac_start_bank, z80_dac_start_addr_high/low,
; z80_bank_number) because other code writes to them.
;
; Shared RAM used by the 68000 (names as in src/sound/sound.asm):
;   $00BE-$00C3  z80_sfxparam1 .. z80_sfxparam5   SFX (DAC sample) mailbox
;   $0273-$02A2  z80_channel_data_buffer          6 x 8-byte FM channel slots
;   $02A3        z80_audio_update_flag            0 = new slot data to process
;   $02A5-       z80_fm_patches                   FM patches, 32 bytes each
;                (68000: Z80_Program_Code+$2A5, instrument command $80)
;
; Assembler notes: asm80 labels are not case sensitive. Every byte of the
; output must equal the retail ROM; the build compares it with the bytes
; at $116A6 in the ROM before using it.
; =============================================================================

        .binfrom 0
        .binto   Z80_DriverLastByte     ; output the whole $598-byte image

; -----------------------------------------------------------------------------
; Hardware (Z80 address space on the Genesis)
; -----------------------------------------------------------------------------
YM2612_ADDR1        EQU $4000   ; YM2612 part I register select (FM ch 1-3, globals)
YM2612_DATA1        EQU $4001   ; YM2612 part I data
YM2612_ADDR2        EQU $4002   ; YM2612 part II register select (FM ch 4-6)
YM2612_DATA2        EQU $4003   ; YM2612 part II data
BANK_REGISTER       EQU $6000   ; 68000 bank select: 9 serial writes of bit 0
BANK_WINDOW         EQU $8000   ; 32 KB window onto 68000 memory
Z80_STACK_TOP       EQU $1FFF   ; Stack starts at the top of the 8 KB Z80 RAM

; YM2612 registers the driver writes
YM_LFO_TIMER_KEY    EQU $28     ; Key on/off: bits 0-2 channel code, bits 4-7 operators
YM_DAC_DATA         EQU $2A     ; DAC sample byte
YM_DAC_ENABLE       EQU $2B     ; Bit 7: channel 6 plays the DAC
YM_TL_OP4           EQU $4C     ; Total level, operator 4 (+ channel 0-2)
YM_FNUM_LOW         EQU $A0     ; Frequency number low 8 bits (+ channel 0-2)
YM_FNUM_HIGH        EQU $A4     ; Block (octave) and frequency high bits (+ channel 0-2)

YM_KEY_ON_ALL_OPS   EQU $F0     ; Added to the channel code: all 4 operators on
DAC_ENABLED         EQU $80     ; YM_DAC_ENABLE value: DAC on
DAC_DISABLED        EQU $00     ; YM_DAC_ENABLE value: DAC off

; z80_dac_state values (byte at $02A4)
DAC_STATE_START     EQU $00     ; Start the requested sample on the next pass
DAC_STATE_PLAYING   EQU $01     ; A sample is playing
DAC_STATE_IDLE      EQU $FF     ; Nothing playing (negative)

; Sample data: a 0 byte ends the sample. If the byte after the 0 is
; SAMPLE_LOOP_MARK the sample restarts from its start address.
SAMPLE_LOOP_MARK    EQU $01

NO_CHANGE           EQU $FF     ; Slot fields with bit 7 set mean "nothing to do";
                                ; the driver writes $FF back once a field is done

; One FM channel slot in z80_channel_data_buffer (8 bytes, 68000 names from
; sound.asm, built at ws_z80_buffer and copied to the Z80 every update)
z80slot_patch_flag      EQU 0   ; Bit 7 clear: load the patch at offset_high/low
z80slot_offset_high     EQU 1   ; Z80 address of the patch, high byte
z80slot_offset_low      EQU 2   ; Z80 address of the patch, low byte
z80slot_keyon           EQU 3   ; Bit 7 clear: key event; bit 0 set = key on, clear = key off
z80slot_freq_update     EQU 4   ; Bit 7 clear: write coarse/fine frequency
z80slot_coarse_freq     EQU 5   ; Value for YM_FNUM_HIGH (block + fnum high)
z80slot_fine_freq       EQU 6   ; Value for YM_FNUM_LOW
z80slot_volume          EQU 7   ; Bit 7 clear: value for YM_TL_OP4 (carrier level)
Z80SLOT_SIZE            EQU 8

; =============================================================================
; $0000: entry after reset
; =============================================================================
Z80_DriverStart:
        jp      Z80_Init                ; Z80 starts here when the 68000 releases reset

        ; $0003-$0037: unused, zero. Z80_Init lands on $0038, which is also
        ; the IM 1 / RST 38h vector, but the driver runs with interrupts off.
        ds      $0038-$, 0              ; pad to $0038

; =============================================================================
; $0038: init and main loop
; =============================================================================
        org     $0038
Z80_Init:
        di                              ; Interrupts are never enabled
        ld      sp, Z80_STACK_TOP
        im      0                       ; Unclear why IM 0; interrupts stay disabled

; Main loop. One pass plays one DAC byte (or none when idle), services the
; FM update the 68000 may have posted, then waits z80_dac_rate loops.
; HL holds the bank-window address of the next sample byte while playing.
MainLoop:
        ld      a, (z80_dac_state)
        or      a
        jr      z, DacStartSample       ; DAC_STATE_START: (re)start the sample
        jp      m, ServiceFmUpdate      ; DAC_STATE_IDLE: no DAC, just FM
        ; DAC_STATE_PLAYING
        ld      a, YM_DAC_DATA
        ld      (YM2612_ADDR1), a       ; Select the DAC data register now; written below
        ld      b, (hl)                 ; B = next sample byte
        inc     hl
        ld      a, h
        or      l
        jr      nz, DacOutputByte       ; HL wrapped past $FFFF: end of the bank window
        ; Step to the next 32 KB bank and restart at the window base
        ld      a, (z80_bank_number)
        inc     a
        ld      (z80_bank_number), a    ; Operand of SetBank's "ld a,n"
        call    SetBank
        ld      hl, BANK_WINDOW
        ld      b, (hl)                 ; Re-read the byte from the new bank
        inc     hl

DacOutputByte:
        ld      a, b
        or      a
        jr      z, DacSampleEnd         ; 0 = end of sample (or loop)
        ld      (YM2612_DATA1), a       ; Output the byte on the DAC

; Write the FM channel slots if the 68000 posted an update this frame.
ServiceFmUpdate:
        ld      a, (z80_audio_update_flag)
        cp      1
        jr      z, DacRateDelay         ; 1 = nothing new
        push    hl                      ; Keep the sample pointer
        call    UpdateFmChannels
        pop     hl
        ld      a, 1
        ld      (z80_audio_update_flag), a ; Mark the update as done

; Delay between DAC bytes: the operand is the sample rate value the 68000
; sends in z80_sfxparam3 ($C1), copied here by CheckSfxRequest.
DacRateDelay:
        ld      b, $19                  ; Operand = z80_dac_rate (retail initial value $19)
z80_dac_rate        EQU DacRateDelay+1
DacRateDelay_delay:
        nop
        djnz    DacRateDelay_delay
        jr      MainLoop

; A 0 byte was read: loop the sample if the next byte is SAMPLE_LOOP_MARK,
; otherwise stop the DAC.
DacSampleEnd:
        ld      a, (hl)
        cp      SAMPLE_LOOP_MARK
        jr      z, DacStartSample
        ld      a, YM_DAC_ENABLE
        ld      (YM2612_ADDR1), a
        push    hl                      ; push/pop: delay between YM2612 writes
        pop     hl
        ld      a, DAC_DISABLED
        ld      (YM2612_DATA1), a
        ld      a, DAC_STATE_IDLE
        ld      (z80_dac_state), a
        ld      (z80_dac_priority), a   ; $FF: any priority can start a sample
        jr      MainLoop

; Start (or restart) the sample: DAC on, select its bank, point HL at its
; start. The bank and address are in the operands below, written by
; CheckSfxRequest from the SFX mailbox.
DacStartSample:
        ld      a, YM_DAC_ENABLE
        ld      (YM2612_ADDR1), a
        push    hl                      ; push/pop: delay between YM2612 writes
        pop     hl
        ld      a, DAC_ENABLED
        ld      (YM2612_DATA1), a
DacStartSample_load_bank:
        ld      a, 0                    ; Operand = z80_dac_start_bank
z80_dac_start_bank  EQU DacStartSample_load_bank+1
        ld      (z80_bank_number), a
        call    SetBank
DacStartSample_load_addr_high:
        ld      h, 0                    ; Operand = z80_dac_start_addr_high ($80 | address bits 8-14)
z80_dac_start_addr_high EQU DacStartSample_load_addr_high+1
DacStartSample_load_addr_low:
        ld      l, 0                    ; Operand = z80_dac_start_addr_low
z80_dac_start_addr_low  EQU DacStartSample_load_addr_low+1
        inc     hl                      ; The byte at the start address itself is skipped
        ld      a, DAC_STATE_PLAYING
        ld      (z80_dac_state), a
        jp      MainLoop

        db      0, 0                    ; $00BC-$00BD: unused

; =============================================================================
; $00BE: SFX (DAC sample) mailbox, written by the 68000 (p_music_vblank_fn, from
; the 6 bytes Sound_WriteYM2612 leaves at z80_write_buffer). Names as in
; sound.asm; the meaning is in each comment. Initial values are the retail bytes.
; =============================================================================
z80_sfxparam1:          db  $00     ; $BE: sample address low byte (68000 address bits 0-7)
z80_sfx_control_ram:    db  $00     ; $BF: sample address high byte | $80 (window address bits 8-15)
z80_sfxparam2:          db  $FF     ; $C0: request flag: 0 = new request, $FF = none / taken
z80_sfxparam3:          db  $00     ; $C1: sample rate (delay loop count -> z80_dac_rate)
z80_sfxparam4:          db  $00     ; $C2: bank (68000 address bits 15-23 -> z80_dac_start_bank)
z80_sfxparam5:          db  $00     ; $C3: priority of the request (lower value wins)
z80_dac_priority:       db  $FF     ; $C4: priority of the sample playing, $FF = none

; =============================================================================
; $00C5: YM2612 registers of one patch, in the order the 32-byte patch stores
; them. Each is added to the channel number (0-2) when written. 0 ends the list.
; =============================================================================
FmPatchRegisters:
        db      $30, $38, $34, $3C      ; DT/MUL,  operators 1, 3, 2, 4 (register order)
        db      $40, $48, $44, $4C      ; TL
        db      $50, $58, $54, $5C      ; RS/AR
        db      $60, $68, $64, $6C      ; AM/D1R
        db      $70, $78, $74, $7C      ; D2R
        db      $80, $88, $84, $8C      ; D1L/RR
        db      $B0                     ; Feedback / algorithm
        db      $B4                     ; Stereo / AMS / PMS
        db      0                       ; End of list

; =============================================================================
; UpdateFmChannels ($00E0)
; Writes the six slots of z80_channel_data_buffer to the YM2612, then checks
; the SFX mailbox for a new DAC sample request.
; Each slot is passed in IX, with C = its YM2612 key-on channel code
; (0-2 = part I channels 1-3, 4-6 = part II channels 4-6; bit 2 = part II).
; =============================================================================
UpdateFmChannels:
        ld      ix, z80_channel_data_buffer+0*Z80SLOT_SIZE
        ld      c, 0
        call    UpdateChannelSlot
        ld      ix, z80_channel_data_buffer+1*Z80SLOT_SIZE
        ld      c, 1
        call    UpdateChannelSlot
        ld      ix, z80_channel_data_buffer+2*Z80SLOT_SIZE
        ld      c, 2
        call    UpdateChannelSlot
        ld      ix, z80_channel_data_buffer+3*Z80SLOT_SIZE
        ld      c, 4
        call    UpdateChannelSlot
        ld      ix, z80_channel_data_buffer+4*Z80SLOT_SIZE
        ld      c, 5
        call    UpdateChannelSlot
        ld      ix, z80_channel_data_buffer+5*Z80SLOT_SIZE
        ld      c, 6
        call    UpdateChannelSlot

; CheckSfxRequest: take a pending DAC sample request if its priority is
; equal to or better (lower) than the sample playing.
CheckSfxRequest:
        ld      a, (z80_sfxparam2)
        or      a
        jr      nz, CheckSfxRequest_done               ; No request
        ld      a, (z80_dac_priority)
        ld      b, a
        ld      a, (z80_sfxparam5)      ; Priority of the request
        cp      b
        jr      z, CheckSfxRequest_accept              ; Same priority: replace
        jr      nc, CheckSfxRequest_reject             ; Higher number than the playing one: refuse
CheckSfxRequest_accept:
        ld      (z80_dac_priority), a
        ld      a, (z80_sfxparam2)      ; 0
        ld      (z80_dac_state), a      ; DAC_STATE_START
        ld      a, NO_CHANGE
        ld      (z80_sfxparam2), a      ; Request taken
        ld      a, (z80_sfxparam4)
        ld      (z80_dac_start_bank), a
        ld      a, (z80_sfxparam1)
        ld      (z80_dac_start_addr_low), a
        ld      a, (z80_sfx_control_ram)
        ld      (z80_dac_start_addr_high), a
        ld      a, (z80_sfxparam3)
        ld      (z80_dac_rate), a
CheckSfxRequest_done:
        ret
CheckSfxRequest_reject:
        ld      a, NO_CHANGE
        ld      (z80_sfxparam2), a      ; Drop the request
        ret

; =============================================================================
; UpdateChannelSlot ($0155)
; IX = slot, C = channel code. Each field with bit 7 clear is written to
; the YM2612 and then set back to $FF.
; =============================================================================
UpdateChannelSlot:
        bit     7, (ix+z80slot_patch_flag)
        call    z, LoadPatch
        bit     7, (ix+z80slot_keyon)
        jr      nz, UpdateChannelSlot_freq
        bit     0, (ix+z80slot_keyon)
        jr      z, UpdateChannelSlot_key_off
        call    KeyOnChannel
        jr      UpdateChannelSlot_freq
UpdateChannelSlot_key_off:
        call    KeyOffChannel
UpdateChannelSlot_freq:
        bit     7, (ix+z80slot_freq_update)
        jr      nz, UpdateChannelSlot_volume
        call    SetChannelFrequency
UpdateChannelSlot_volume:
        bit     7, (ix+z80slot_volume)
        jr      nz, UpdateChannelSlot_done
        call    SetChannelVolume
UpdateChannelSlot_done:
        ret

; -----------------------------------------------------------------------------
; LoadPatch: write the 26 register bytes of the patch at
; (z80slot_offset_high/low) to this channel, in FmPatchRegisters order.
; IX = slot, C = channel code (preserved).
; -----------------------------------------------------------------------------
LoadPatch:
        ld      b, c                    ; Keep the channel code
        ld      h, (ix+z80slot_offset_high)
        ld      l, (ix+z80slot_offset_low) ; HL = patch
        ld      de, FmPatchRegisters
        bit     2, c
        jr      nz, LoadPatch_part2
LoadPatch_part1_loop:
        ld      a, (de)
        cp      0
        jr      z, LoadPatch_done
        add     a, c                    ; Register + channel
        push    bc
        ld      c, (hl)
        call    WriteYmPart1
        pop     bc
        inc     hl
        inc     de
        jr      LoadPatch_part1_loop
LoadPatch_done:
        ld      a, NO_CHANGE
        ld      (ix+z80slot_patch_flag), a
        ld      c, b                    ; Restore the channel code
        ret
LoadPatch_part2:
        ld      a, c
        and     3                       ; Channel 4-6 -> 0-2 within part II
        ld      c, a
LoadPatch_part2_loop:
        ld      a, (de)
        cp      0
        jr      z, LoadPatch_done
        add     a, c
        push    bc
        ld      c, (hl)
        call    WriteYmPart2
        pop     bc
        inc     hl
        inc     de
        jr      LoadPatch_part2_loop

; -----------------------------------------------------------------------------
; KeyOnChannel: key off then key on all 4 operators (retriggers the note).
; C = channel code (preserved).
; -----------------------------------------------------------------------------
KeyOnChannel:
        ld      b, c
        ld      a, YM_LFO_TIMER_KEY
        call    WriteYmPart1            ; Key off
        ld      a, b
        add     a, YM_KEY_ON_ALL_OPS
        ld      c, a
        ld      a, YM_LFO_TIMER_KEY
        call    WriteYmPart1            ; Key on
        ld      a, NO_CHANGE
        ld      (ix+z80slot_keyon), a
        ld      c, b
        ret

; -----------------------------------------------------------------------------
; KeyOffChannel: key off all operators. C = channel code.
; -----------------------------------------------------------------------------
KeyOffChannel:
        ld      a, YM_LFO_TIMER_KEY
        call    WriteYmPart1
        ld      a, NO_CHANGE
        ld      (ix+z80slot_keyon), a
        ret

; -----------------------------------------------------------------------------
; SetChannelFrequency: write z80slot_coarse_freq to $A4+ch, then
; z80slot_fine_freq to $A0+ch (the high register must be written first).
; C = channel code (preserved).
; -----------------------------------------------------------------------------
SetChannelFrequency:
        ld      e, c                    ; Keep the channel code
        bit     2, c
        jr      nz, SetChannelFrequency_part2
        ld      b, c
        ld      d, (ix+z80slot_coarse_freq)
        ld      a, YM_FNUM_HIGH
        add     a, c
        ld      c, d
        call    WriteYmPart1
        ld      d, (ix+z80slot_fine_freq)
        ld      a, YM_FNUM_LOW
        add     a, b
        ld      c, d
        call    WriteYmPart1
        ld      a, NO_CHANGE
        ld      (ix+z80slot_freq_update), a
        ld      c, e
        ret
SetChannelFrequency_part2:
        ld      a, c
        and     3
        ld      c, a
        ld      b, c
        ld      d, (ix+z80slot_coarse_freq)
        ld      a, YM_FNUM_HIGH
        add     a, c
        ld      c, d
        call    WriteYmPart2
        ld      d, (ix+z80slot_fine_freq)
        ld      a, YM_FNUM_LOW
        add     a, b
        ld      c, d
        call    WriteYmPart2
        ld      a, NO_CHANGE
        ld      (ix+z80slot_freq_update), a
        ld      c, e
        ret

; -----------------------------------------------------------------------------
; SetChannelVolume: write z80slot_volume to the operator 4 total level
; ($4C+ch). Operator 4 is a carrier in every algorithm, so this sets the
; channel's output level. Leaves C = the value written (callers reload C).
; -----------------------------------------------------------------------------
SetChannelVolume:
        bit     2, c
        jr      nz, SetChannelVolume_part2
        ld      a, YM_TL_OP4
        add     a, c
        ld      c, (ix+z80slot_volume)
        call    WriteYmPart1
        ld      a, NO_CHANGE
        ld      (ix+z80slot_volume), a
        ret
SetChannelVolume_part2:
        ld      a, c
        and     3
        add     a, YM_TL_OP4
        ld      c, (ix+z80slot_volume)
        call    WriteYmPart2
        ld      a, NO_CHANGE
        ld      (ix+z80slot_volume), a
        ret

; -----------------------------------------------------------------------------
; WriteYmPart1 / WriteYmPart2: A = register, C = data. Three push/pop pairs
; between the register select and the data write give the YM2612 time
; (the driver never polls the busy flag).
; -----------------------------------------------------------------------------
WriteYmPart1:
        ld      (YM2612_ADDR1), a
        push    hl
        pop     hl
        push    hl
        pop     hl
        push    hl
        pop     hl
        ld      a, c
        ld      (YM2612_DATA1), a
        ret

WriteYmPart2:
        ld      (YM2612_ADDR2), a
        push    hl
        pop     hl
        push    hl
        pop     hl
        push    hl
        pop     hl
        ld      a, c
        ld      (YM2612_DATA2), a
        ret

; -----------------------------------------------------------------------------
; UnusedDacWriteIY ($025E): not called from anywhere in the driver. Writes
; the byte at IY to the DAC and advances IY unless it is 0. Looks like a
; leftover IY-based DAC routine; its purpose is unclear.
; -----------------------------------------------------------------------------
UnusedDacWriteIY:
        ld      a, YM_DAC_DATA
        ld      (YM2612_ADDR1), a
        nop
        nop
        nop
        ld      a, (iy+0)
        cp      0
        jr      z, UnusedDacWriteIY_done
        inc     iy
        ld      (YM2612_DATA1), a
UnusedDacWriteIY_done:
        ret

; =============================================================================
; $0273: z80_channel_data_buffer: 6 FM channel slots (z80slot_* layout),
; copied by the 68000 from $FFFFFFB6 (48 bytes) on each update. The initial
; values are the retail bytes; the 68000 overwrites them on its first update
; (they look like leftover build-time data, meaning unclear).
; =============================================================================
z80_channel_data_buffer:
        db      $FF, $82, $C5, $FF, $FF, $12, $00, $FF  ; Slot 0: key code 0 (FM 1)
        db      $FF, $02, $C5, $FF, $FF, $00, $00, $FF  ; Slot 1: key code 1 (FM 2)
        db      $FF, $02, $C5, $FF, $FF, $00, $00, $FF  ; Slot 2: key code 2 (FM 3)
        db      $FF, $02, $C5, $FF, $FF, $12, $00, $FF  ; Slot 3: key code 4 (FM 4)
        db      $FF, $02, $C5, $FF, $FF, $00, $00, $FF  ; Slot 4: key code 5 (FM 5)
        db      $FF, $02, $C5, $FF, $FF, $00, $00, $FF  ; Slot 5: key code 6 (FM 6)

z80_audio_update_flag:
        db      $00     ; $02A3: 68000 writes 0 when the slots hold new data (or 1
                        ; for none); the driver sets 1 once it has written them
z80_dac_state:
        db      DAC_STATE_IDLE ; $02A4: DAC_STATE_START / _PLAYING / _IDLE

; =============================================================================
; $02A5: z80_fm_patches: 22 FM patches, 32 bytes each. The 68000 instrument
; command ($80 n) points a slot at $02A5 + n*32 and reads byte $1A itself.
; Per patch:
;   +$00-$17  4 bytes per register group, in FmPatchRegisters order
;             (operators 1, 3, 2, 4): DT/MUL, TL, RS/AR, AM/D1R, D2R, D1L/RR
;   +$18      $B0 feedback / algorithm
;   +$19      $B4 stereo / AMS / PMS
;   +$1A      note offset, read by the 68000 (channel_note_offset); not sent
;   +$1B-$1F  unused, zero
; =============================================================================
z80_fm_patches:
; Patch 0 ($02A5)
FmPatch0:
        db      $00, $20, $62, $10  ; DT/MUL
        db      $17, $0C, $12, $0A  ; TL
        db      $1F, $1F, $1F, $07  ; RS/AR
        db      $04, $04, $04, $04  ; AM/D1R
        db      $00, $00, $00, $00  ; D2R
        db      $F9, $F9, $F9, $F9  ; D1L/RR
        db      $0A, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 1 ($02C5)
FmPatch1:
        db      $36, $43, $00, $01  ; DT/MUL
        db      $19, $20, $20, $0E  ; TL
        db      $5F, $5C, $5D, $5F  ; RS/AR
        db      $06, $09, $02, $05  ; AM/D1R
        db      $06, $04, $01, $00  ; D2R
        db      $23, $33, $13, $08  ; D1L/RR
        db      $28, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 2 ($02E5)
FmPatch2:
        db      $22, $72, $72, $32  ; DT/MUL
        db      $13, $1A, $10, $1A  ; TL
        db      $10, $11, $0D, $10  ; RS/AR
        db      $08, $00, $06, $02  ; AM/D1R
        db      $00, $00, $00, $00  ; D2R
        db      $37, $09, $27, $09  ; D1L/RR
        db      $2C, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 3 ($0305)
FmPatch3:
        db      $00, $04, $70, $00  ; DT/MUL
        db      $00, $00, $10, $08  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $0D, $00, $16, $0F  ; AM/D1R
        db      $00, $0F, $07, $14  ; D2R
        db      $F5, $FA, $68, $FC  ; D1L/RR
        db      $02, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 4 ($0325)
FmPatch4:
        db      $0F, $03, $01, $01  ; DT/MUL
        db      $00, $00, $00, $00  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $00, $03, $14, $18  ; AM/D1R
        db      $00, $0E, $08, $0E  ; D2R
        db      $05, $08, $75, $08  ; D1L/RR
        db      $3C, $C0  ; $B0 fb/alg, $B4 stereo
        db      $FD  ; Note offset (-3)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 5 ($0345)
FmPatch5:
        db      $3C, $39, $00, $14  ; DT/MUL
        db      $19, $28, $00, $10  ; TL
        db      $DF, $1F, $1F, $DF  ; RS/AR
        db      $04, $05, $04, $01  ; AM/D1R
        db      $04, $04, $04, $02  ; D2R
        db      $F7, $07, $17, $AC  ; D1L/RR
        db      $38, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 6 ($0365)
FmPatch6:
        db      $56, $15, $10, $72  ; DT/MUL
        db      $2C, $2C, $17, $0E  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $02, $03, $07, $00  ; AM/D1R
        db      $07, $07, $07, $06  ; D2R
        db      $F0, $F5, $F6, $F8  ; D1L/RR
        db      $28, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 7 ($0385)
FmPatch7:
        db      $31, $01, $10, $21  ; DT/MUL
        db      $39, $1A, $0E, $16  ; TL
        db      $1F, $1F, $5F, $1F  ; RS/AR
        db      $03, $04, $1F, $1F  ; AM/D1R
        db      $07, $00, $0A, $00  ; D2R
        db      $0F, $0F, $0F, $0F  ; D1L/RR
        db      $2C, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 8 ($03A5)
FmPatch8:
        db      $5F, $52, $07, $02  ; DT/MUL
        db      $00, $28, $1C, $0C  ; TL
        db      $1F, $1F, $1F, $9F  ; RS/AR
        db      $15, $15, $15, $1F  ; AM/D1R
        db      $13, $0C, $0D, $10  ; D2R
        db      $26, $26, $36, $09  ; D1L/RR
        db      $3B, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 9 ($03C5)
FmPatch9:
        db      $00, $04, $7F, $00  ; DT/MUL
        db      $09, $12, $13, $0A  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $0F, $00, $12, $11  ; AM/D1R
        db      $00, $0F, $07, $00  ; D2R
        db      $FF, $FA, $68, $F9  ; D1L/RR
        db      $28, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 10 ($03E5)
FmPatch10:
        db      $00, $02, $70, $00  ; DT/MUL
        db      $00, $00, $13, $05  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $08, $00, $12, $0C  ; AM/D1R
        db      $00, $0F, $07, $00  ; D2R
        db      $F5, $FA, $68, $FC  ; D1L/RR
        db      $02, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 11 ($0405)
FmPatch11:
        db      $30, $20, $40, $77  ; DT/MUL
        db      $0D, $00, $60, $07  ; TL
        db      $1F, $1F, $1F, $08  ; RS/AR
        db      $00, $1F, $1F, $1F  ; AM/D1R
        db      $00, $00, $00, $00  ; D2R
        db      $09, $9F, $09, $09  ; D1L/RR
        db      $3A, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 12 ($0425)
FmPatch12:
        db      $31, $20, $40, $77  ; DT/MUL
        db      $05, $7F, $7F, $0A  ; TL
        db      $11, $00, $00, $0E  ; RS/AR
        db      $00, $1F, $1F, $0C  ; AM/D1R
        db      $00, $00, $00, $00  ; D2R
        db      $09, $9F, $9F, $9A  ; D1L/RR
        db      $32, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 13 ($0445)
FmPatch13:
        db      $00, $02, $70, $00  ; DT/MUL
        db      $12, $00, $12, $05  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $00, $00, $12, $0D  ; AM/D1R
        db      $00, $0F, $07, $00  ; D2R
        db      $F5, $FA, $68, $FC  ; D1L/RR
        db      $1A, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 14 ($0465)
FmPatch14:
        db      $02, $02, $01, $01  ; DT/MUL
        db      $20, $30, $10, $07  ; TL
        db      $1F, $1F, $1F, $12  ; RS/AR
        db      $1F, $1F, $1F, $00  ; AM/D1R
        db      $03, $00, $00, $00  ; D2R
        db      $15, $05, $D5, $FA  ; D1L/RR
        db      $33, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 15 ($0485)
FmPatch15:
        db      $00, $F5, $F0, $FF  ; DT/MUL
        db      $00, $00, $00, $03  ; TL
        db      $D8, $88, $88, $88  ; RS/AR
        db      $00, $1D, $1D, $1D  ; AM/D1R
        db      $07, $06, $06, $06  ; D2R
        db      $D9, $99, $99, $F9  ; D1L/RR
        db      $3B, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 16 ($04A5)
FmPatch16:
        db      $01, $01, $31, $31  ; DT/MUL
        db      $12, $00, $0A, $0A  ; TL
        db      $4D, $10, $0F, $0F  ; RS/AR
        db      $04, $1F, $03, $03  ; AM/D1R
        db      $00, $00, $04, $04  ; D2R
        db      $07, $A9, $E8, $E7  ; D1L/RR
        db      $2D, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 17 ($04C5)
FmPatch17:
        db      $35, $30, $00, $14  ; DT/MUL
        db      $2C, $50, $00, $0C  ; TL
        db      $DF, $1F, $1F, $DF  ; RS/AR
        db      $04, $05, $04, $01  ; AM/D1R
        db      $04, $04, $04, $02  ; D2R
        db      $F5, $05, $15, $85  ; D1L/RR
        db      $21, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 18 ($04E5)
FmPatch18:
        db      $56, $15, $10, $72  ; DT/MUL
        db      $23, $2F, $18, $0C  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $02, $03, $02, $03  ; AM/D1R
        db      $07, $07, $06, $05  ; D2R
        db      $F0, $F5, $F6, $F8  ; D1L/RR
        db      $28, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 19 ($0505)
FmPatch19:
        db      $00, $02, $70, $00  ; DT/MUL
        db      $00, $00, $13, $09  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $08, $00, $12, $0C  ; AM/D1R
        db      $00, $0F, $07, $00  ; D2R
        db      $F5, $FA, $68, $FC  ; D1L/RR
        db      $02, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 20 ($0525)
FmPatch20:
        db      $00, $02, $70, $00  ; DT/MUL
        db      $00, $00, $13, $0D  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $08, $00, $12, $0C  ; AM/D1R
        db      $00, $0F, $07, $00  ; D2R
        db      $F5, $FA, $68, $FC  ; D1L/RR
        db      $02, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused
; Patch 21 ($0545)
FmPatch21:
        db      $56, $15, $10, $72  ; DT/MUL
        db      $28, $43, $16, $0D  ; TL
        db      $1F, $1F, $1F, $1F  ; RS/AR
        db      $03, $03, $08, $08  ; AM/D1R
        db      $07, $07, $06, $05  ; D2R
        db      $F0, $F5, $F6, $F8  ; D1L/RR
        db      $28, $C0  ; $B0 fb/alg, $B4 stereo
        db      $00  ; Note offset (+0)
        db      $00, $00, $00, $00, $00  ; Unused

        db      0, 0, 0, 0              ; $0565-$0568: unused, zero

; =============================================================================
; SetBank ($0569): select the 32 KB bank of 68000 memory seen at
; BANK_WINDOW. The register takes 9 serial writes of bit 0 (68000 address
; bits 15-23, low bit first). The bank number is the operand of the first
; instruction, z80_bank_number, written by the DAC code before each call.
; =============================================================================
SetBank:
        ld      a, 0                    ; Operand = z80_bank_number
z80_bank_number     EQU SetBank+1
        ld      (BANK_REGISTER), a      ; Bit 15
        srl     a
        ld      (BANK_REGISTER), a      ; Bit 16
        srl     a
        ld      (BANK_REGISTER), a      ; Bit 17
        srl     a
        ld      (BANK_REGISTER), a      ; Bit 18
        srl     a
        ld      (BANK_REGISTER), a      ; Bit 19
        srl     a
        ld      (BANK_REGISTER), a      ; Bit 20
        srl     a
        ld      (BANK_REGISTER), a      ; Bit 21
        srl     a
        ld      (BANK_REGISTER), a      ; Bit 22
        ld      a, 0
        ld      (BANK_REGISTER), a      ; Bit 23 = 0
        ret

; $0597: last byte of the ROM range ($11C3D). Sound_LoadZ80Program copies
; only $597 bytes, so this byte never reaches Z80 RAM and nothing reads it.
; Kept so the ROM stays identical; what it is is unclear.
Z80_DriverLastByte:
        db      $6E
