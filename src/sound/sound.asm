; NHL 92 Sega Genesis Sound Code Disassembly
; Address Range: 0xF4C8 - 0x24214
; Fully Commented and Labeled
; Handles music and sound effects via Z80 and YM2612 sound chip

; Data Location
fm_instrument_patch_sfx_id_3 = $12DE2 ; 12DE2 - 12A58 (sfx_puckwall1_pcm) - F4C8
fm_instrument_patch_sfx_31 = $10820

; Z80 Memory Map
z80_ram = $A00000
z80_sfxparam1 = $A000BE
z80_sfx_control_ram = $A000BF
z80_sfxparam2 = $A000C0
z80_sfxparam3 = $A000C1
z80_sfxparam4 = $A000C2
z80_sfxparam5 = $A000C3
z80_channel_data_buffer_RAM = $A00273
z80_audio_update_flag = $A002A3
IO_Z80RES           EQU $A11200      ; Z80 reset port
IO_Z80BUS           EQU $A11100      ; Z80 bus request port

; Memory Definitions
g_sfxchannel0activeflag = $FFFFFE40
g_sfxchannel1activeflag = $FFFFFE88
g_sfxchannel2activeflag = $FFFFFED0
g_sfxchannel3activeflag = $FFFFFF18
g_sfxchannel4activeflag = $FFFFFF60
g_sfxchannel5activeflag = $FFFFFFA8
g_Channel0Volume = $FFFFFFB9
g_Channel1Volume = $FFFFFFC1
g_Channel2Volume = $FFFFFFC9
g_Channel3Volume = $FFFFFFD1
g_Channel4Volume = $FFFFFFD9
g_Channel5Volume = $FFFFFFE1
z80_write_buffer = $FFFFFFE6
z80_update_flag = $FFFFFFE8
ym2612_data_low = $FFFFFFE9
ym2612_reg_part = $FFFFFFEA
ym2612_data_high = $FFFFFFEB
z80_write_pending = $FFFFFFEC
g_MusicPauseFlag = $FFFFFFED
g_AudioStopFlag     EQU $FFFFFFF4      ; Byte: Flag to stop all audio (1 = stop)

; Sound Workspace Memory
g_SoundWorkspace    EQU $FFFFFDFC    ; Base address of sound workspace in 68000 memory
g_CurrentTrackID    EQU $FFFFFFB2    ; Long: Current music track ID
g_MusicStopFlag     EQU $FFFFFFF3    ; Byte: Flag to stop music (1 = stop)
g_MusicInitFlag     EQU $FFFFFFF5    ; Byte: Flag to initialize music (1 = init)
g_AudioUpdateFlag   EQU $FFFFFFF9    ; Byte: Flag to update Z80 audio data (1 = update)

; Channel Structure (size $48 bytes)
channel_flags           EQU 0    ; Byte: Flags (bit 1: modulation, bit 2: ?, bit 3: active)
channel_pitch_adjust    EQU 3    ; Byte: Pitch adjustment value
channel_current_pos     EQU 4    ; Long: Current position in track data
channel_base_ptr        EQU 8    ; Long: Base pointer to track data
channel_loop_ptr        EQU $C   ; Long: Pointer for loops or subroutines
channel_duration        EQU $10  ; Word: Note duration counter
channel_freq_low        EQU $12  ; Word: Frequency low part
channel_octave          EQU $13  ; Byte: Octave value
channel_freq_high_part  EQU $14  ; Byte: Frequency high part
channel_envelope_param  EQU $15  ; Byte: Envelope parameter
channel_modulation_val  EQU $16  ; Byte: Modulation value
channel_envelope_current EQU $1C ; Long: Current envelope position
channel_envelope_base   EQU $20  ; Long: Base envelope pointer
channel_note_offset     EQU $24  ; Byte: Note offset from instrument
channel_note_counter    EQU $25  ; Byte: Note counter
channel_timing          EQU $26  ; Word: Timing or delay value
channel_effect_current  EQU $28  ; Long: Current sound effect position
channel_effect_base     EQU $2C  ; Long: Base sound effect pointer
channel_freq_data       EQU $30  ; Long: Sound effect frequency data
channel_current_freq    EQU $34  ; Long: Current frequency for effects
channel_freq_increment  EQU $38  ; Long: Frequency increment for effects
channel_freq_counter    EQU $3C  ; Byte: Frequency update counter
channel_delay_counter   EQU $3D  ; Byte: Delay counter for effects
channel_effect_state    EQU $3E  ; Byte: Effect state (0=inactive, 1=playing, 3=stopping)
channel_initial_freq_counter EQU $40 ; Byte: Initial frequency counter
channel_instrument_id   EQU $41  ; Byte: Current instrument ID
channel_modulation_counter EQU $42 ; Byte: Modulation counter
channel_loop_counter    EQU $44  ; Long: Loop counter

; Sound Code Entry Points
p_music_vblank:               ; (VBlank handler)
    bra.w   p_music_vblank_fn ; Jump to VBlank sound update routine
p_initialZ80:                 ; (Initialization)
    bra.w   p_initialZ80_fn   ; Jump to Z80 initialization routine
p_initune:                    ; (Music trigger)
    bra.w   p_initune_fn      ; Jump to music initialization routine
p_turnoff:                    ; (Audio stop)
    bra.w   p_turnoff_fn      ; Jump to audio shutdown routine
p_initfx:                     ; (SFX trigger)
    bra.w   p_initfx_fn       ; Jump to sound effect initialization routine

; Z80 Initialization Function
p_initialZ80_fn:
    lea     (g_SoundWorkspace).l,a0 ; Load sound workspace base address
    move.w  #$1FF,d0                ; Set loop counter to clear 512 bytes
    moveq   #0,d1                   ; Clear value (0)

clear_workspace_loop:
    move.b  d1,(a0)+                ; Clear byte in workspace
    dbf     d0,clear_workspace_loop ; Loop until all bytes cleared
    move.w  #$100,(IO_Z80RES).l     ; Reset Z80 (active)
    move.w  #$100,(IO_Z80BUS).l     ; Request Z80 bus
    bsr.w   Sound_LoadZ80Program    ; Load Z80 sound program (not shown)
    rts                             ; Return

; Music Track Initialization Function
p_initune_fn:
    move.l  d0,(g_CurrentTrackID).l ; Store track ID (e.g., SngTitle=1)
    move.b  #1,(g_MusicInitFlag).l  ; Set flag to initialize music
    rts                             ; Return

; Initializes the music track based on the current track ID.
; Sets up channel data for up to 6 channels (likely FM/PSG).
; Uses fmtune_pointer_table for track-specific configuration.
Sound_InitMusicTrack:
    move.l  (g_CurrentTrackID).l,d0 ; Load the current music track ID into d0.
    lea     (g_SoundWorkspace).l,a3 ; Load base address of sound workspace into a3.
    lea     p_music_vblank(pc),a4   ; Load base address for music data offsets into a4 (used for PC-relative addressing).
    lea     6(a3),a1                ; Set a1 to point to the first channel structure in workspace (offset 6).
    andi.w  #$FF,d0                 ; Mask track ID to 8 bits (0-255).
    mulu.w  #$1A,d0                 ; Multiply by 26 (size of each entry in fmtune_pointer_table).
    lea     fmtune_pointer_table(pc),a0 ; Load address of track pointer table into a0.
    move.b  (a0,d0.w),4(a3)         ; Store byte from table (likely number of FM channels) at workspace offset 4.
    move.b  1(a0,d0.w),2(a3)        ; Store next byte from table (likely number of PSG channels) at workspace offset 2.
    moveq   #0,d7                   ; Clear d7 (channel index counter, 0 to 5).
.init_channel_loop                  ; Loop to initialize each of the 6 channels.
    move.w  #1,$10(a1)              ; Set tick counter for note duration to 1 (forces immediate processing?).
    clr.w   (a1)                    ; Clear word at channel base (flags or status).
    move.b  #0,$15(a1)              ; Clear envelope index or flag.
    move.b  #0,3(a1)                ; Clear pitch offset or transpose value.
    move.l  #0,$44(a1)              ; Clear loop counter or stack pointer.
    move.b  #$FF,$41(a1)            ; Set instrument ID to $FF (invalid/default?).
    lea     fmtune_pointer_table(pc),a0 ; Reload track table address.
    movea.l 2(a0,d0.w),a0           ; Load long pointer from table +2 + (channel*4) into a0 (channel data start).
    adda.l  a4,a0                   ; Add base offset to make it absolute.
    move.l  a0,8(a1)                ; Store as base pointer for channel (loop reset point?).
    move.l  a0,$C(a1)               ; Store same as current loop stack pointer.
    addq.l  #2,$C(a1)               ; Skip 2 bytes in loop stack (header?).
    movea.w (a0),a0                 ; Load word offset from base pointer into a0.
    adda.l  a4,a0                   ; Add base to make absolute track data pointer.
    move.l  a0,4(a1)                ; Store as current track position pointer.
    adda.w  #$48,A1                 ; Advance a1 to next channel structure (0x48 bytes per channel).
    addq.w  #4,d0                   ; Advance table offset by 4 (next long pointer in table entry).
    addq.w  #1,d7                   ; Increment channel index.
    cmp.w   #6,d7                   ; Check if all 6 channels are done.
    bne.s   .init_channel_loop      ; Loop if not.
    PUSHO                           ; Save current options state
	    OPT OZ-                     ; Disable zero displacement optimization
	    st  0(a3)                   ; Set workspace byte 0 to $FF (enable music flag?).
	    POPO                        ; Restore previous options state
    
    move.b  #1,$1F1(a3)             ; Set another flag at workspace +0x1F1 to 1 (pause or init complete?).
    rts                             ; Return from subroutine.

    lea     (g_SoundWorkspace).l,a3
    cmpi.b  #0,g_MusicPauseFlag-g_SoundWorkspace(a3)
    beq.s   Sound_PauseMusic_Return
    PUSHO                           ; Save current options state
	    OPT OZ-                     ; Disable zero displacement optimization
	    st  0(a3)                   ; Set workspace byte 0 to $FF (enable music flag?).
	    POPO                        ; Restore previous options state
    rts

; Audio Shutdown Function
p_turnoff_fn:
    move.b  #1,(g_AudioStopFlag).l  ; Set flag to stop all audio
    rts                             ; Return

; Stop Music Flag Setter
    move.b  #1,(g_MusicStopFlag).l ; Set flag to stop music
    rts                             ; Return

; Stop Music Function
Sound_StopMusic:
    lea     (g_SoundWorkspace).l,a3     ; Load workspace
    PUSHO                           ; Save current options state
	    OPT OZ-                     ; Disable zero displacement optimization
	    sf  0(a3)                   ; Clear music active flag
	    POPO                        ; Restore previous options state
    bsr.w   Sound_ResetAllSFX           ; Reset all channel data
    bsr.w   configure_ym2612            ; Configure YM2612 chip
    bsr.w   Sound_ResetChannelVolumes   ; Clear output buffers
    rts                                 ; Return

; Pause Music Function
Sound_PauseMusic:
    lea     (g_SoundWorkspace).l,a3     ; Load workspace
    PUSHO                           ; Save current options state
	    OPT OZ-                     ; Disable zero displacement optimization
	    sf  0(a3)                   ; Clear music active flag
	    POPO                        ; Restore previous options state
    move.b  #0,$1F1(a3)                 ; Clear state flag
    bsr.w   Sound_ResetAllSFX           ; Reset all channels
    bsr.w   configure_ym2612            ; Configure YM2612
    bsr.w   Sound_ResetChannelVolumes   ; Clear output buffers

Sound_PauseMusic_Return:
    rts                                 ; Return

; Update Music State Function
Sound_UpdateMusicState:
    cmpi.b  #1,(g_AudioStopFlag).l      ; Check if audio stop requested
    bne.s   .check_music_stop           ; If not, check music stop
    bsr.s   Sound_PauseMusic            ; Pause Ascending ; Pause music
    move.b  #0,(g_AudioStopFlag).l      ; Clear stop flag
    bra.w   .update_state_done          ; Done
.check_music_stop
    cmpi.b  #1,(g_MusicStopFlag).l      ; Check if music stop requested
    bne.s   .check_music_init           ; If not, check init
    bsr.s   Sound_StopMusic             ; Stop music
    move.b  #0,(g_MusicStopFlag).l      ; Clear stop flag
    bra.w   .update_state_done          ; Done
.check_music_init
    cmpi.b  #1,(g_MusicInitFlag).l      ; Check if music init requested
    bne.s   .process_music               ; If not, process music
    bsr.s   Sound_PauseMusic            ; Pause current music
    bsr.w   Sound_InitMusicTrack        ; Initialize new track
    move.b  #0,(g_MusicInitFlag).l      ; Clear init flag
    bra.w   .update_state_done           ; Done
.process_music
    bsr.w   Sound_ProcessMusicChannels    ; Process music tracks
.update_state_done
    rts                                 ; Return

Sound_ProcessMusicChannels: ; Processes all music channels, updating their state, parsing track commands,
                            ; handling notes, modulation, envelopes, and preparing output for Z80.
                            ; Handles up to 6 channels (likely FM and PSG).
                            ; After music channels, it processes sound effects.
    lea     (g_SoundWorkspace).l,a3     ; Load sound workspace base into a3.
    lea     p_music_vblank(pc),a4       ; Load base offset for PC-relative data access into a4.
    PUSHO                           ; Save current options state
	    OPT OZ-                     ; Disable zero displacement optimization
	    tst.b   0(a3)               ; Test music enable flag (byte 0 in workspace).
	    POPO                        ; Restore previous options state
    beq.w   .process_sound_effects      ; If zero (disabled), skip music processing and go to SFX.
    moveq   #0,d7                       ; Clear d7 (channel index, starts at 0).
    move.b  4(a3),d7                    ; Load number of channels to process from workspace offset 4 (from init).
.process_channel                        ; Main loop to process each channel.
    moveq   #0,d0                       ; Clear d0.
    move.w  #$48,d0                     ; Channel structure size (0x48 bytes).
    mulu.w  d7,d0                       ; Compute offset for current channel (d7 * 0x48).
    lea     6(a3),a0                    ; Set a0 to first channel base (workspace +6).
    adda.l  d0,a0                       ; Add offset to point to current channel.
    movea.l 4(a0),a1                    ; Load current track position pointer into a1.
    movea.l $18(a0),a5                  ; Unused? (possibly old modulation pointer, but not used here).
    lea     $1BA(a3),a6                 ; Set a6 to Z80 output buffer area (workspace +0x1BA).
    move.w  d7,d0                       ; Copy channel index to d0.
    lsl.w   #3,d0                       ; Multiply by 8 (size of each channel's output slot).
    adda.l  d0,a6                       ; Add to get pointer to this channel's Z80 data slot.
    subq.w  #1,$10(a0)                  ; Decrement note duration tick counter.
    beq.s   .process_track_data         ; If zero, time to parse new track data.
    cmpi.w  #1,$10(a0)                  ; Check if counter is now 1 (last tick of note).
    bne.w   .update_channel_modulation  ; If not, skip to modulation/envelope update.
    btst    #3,(a0)                     ; Test bit 3 of channel flags (sustain or key-off flag?).
    bne.w   .update_channel_modulation  ; If set, no key-off, go to modulation.
    move.b  #0,3(a6)                    ; Clear Z80 key-on flag (send key-off).
    move.b  #0,(g_AudioUpdateFlag).l    ; Set global audio update flag to 0 (needs update).
    bra.w   .update_channel_modulation  ; Proceed to modulation/envelope.
.process_track_data                     ; Parse commands from track data stream.
    clr.w   (a0)                        ; Clear channel status word.
.parse_track_command                    ; Loop to read and handle track bytes until a note or rest is found.
    moveq   #0,d0                       ; Clear d0.
    move.b  (a1)+,d0                    ; Read next byte from track data into d0, advance pointer.
    bpl.w   .handle_note                ; If positive (0-127), it's a note/rest; .handle it.
    cmp.b   #$84,d0                     ; Compare to $84 (loop command).
    beq.w   .handle_loop                ; If equal, .handle loop.
    cmp.b   #$80,d0                     ; Compare to $80 (instrument).
    beq.s   .handle_instrument          ; If equal, .handle instrument change.
    cmp.b   #$81,d0                     ; Compare to $81 (modulation).
    beq.w   .handle_modulation          ; If equal, .handle modulation setup.
    cmp.b   #$83,d0                     ; Compare to $83 (sustain).
    beq.w   .set_channel_sustain_flag    ; If equal, set sustain flag.
    cmp.b   #$85,d0                     ; Compare to $85 (stop).
    beq.w   .handle_stop                ; If equal, stop music.
    cmp.b   #$86,d0                     ; Compare to $86 (envelope).
    beq.w   .handle_envelope            ; If equal, set envelope.
    cmp.b   #$87,d0                     ; Compare to $87 (clear envelope).
    beq.w   .handle_clear_envelope      ; If equal, clear envelope.
    cmp.b   #$88,d0                     ; Compare to $88 (pitch adjust).
    beq.w   .handle_pitch_adjust        ; If equal, set pitch offset.
    cmp.b   #$89,d0                     ; Compare to $89 (flag set).
    beq.w   .handle_flag_set            ; If equal, set flag bit 3.
    cmp.b   #$8A,d0                     ; Compare to $8A (skip).
    beq.w   .handle_skip                ; If equal, skip bytes.
    cmp.b   #$8B,d0                     ; Compare to $8B (sound effect).
    beq.w   .handle_sound_effect        ; If equal, trigger SFX.
    subi.b  #$A0,d0                     ; Subtract $A0 (for duration commands $8C-$9F?).
    moveq   #0,d1                       ; Clear d1.
    move.b  2(a3),d1                    ; Load tempo multiplier or base duration from workspace +2.
    mulu.w  d1,d0                       ; Multiply adjusted command value by base.
    move.w  d0,$26(a0)                  ; Store as base note duration for channel.
    bra.s   .parse_track_command        ; Continue parsing.
.handle_instrument                      ; Handle $80: Set instrument.
    move.b  (a1)+,d0                    ; Read instrument ID.
    move.l  #$2A5,d1                    ; Base offset for instrument data in Z80 program.
    lea     Z80_Program_Code(pc),a5     ; Load Z80 code base (instrument patches here).
    adda.l  d1,a5                       ; Add base to a5.
    lsl.w   #5,d0                       ; Multiply ID by 32 (instrument size?).
    add.l   d0,d1                       ; Add to d1 (full offset).
    adda.l  d0,a5                       ; Add to a5 (pointer to instrument data).
    move.w  d1,d0                       ; Copy offset to d0.
    move.b  d0,2(a6)                    ; Store low byte of offset in Z80 slot +2.
    lsr.w   #8,d1                       ; Shift high byte.
    move.b  d1,1(a6)                    ; Store high byte in Z80 slot +1.
    move.b  #0,(a6)                     ; Clear Z80 slot +0 (instrument change flag?).
    move.b  #0,(g_AudioUpdateFlag).l    ; Set update flag.
    move.b  $1A(a5),$24(a0)             ; Store byte from instrument +0x1A (octave shift?) to channel +0x24.
    bra.w   .parse_track_command        ; Continue parsing.
.set_channel_sustain_flag               ; Handle $83: Set sustain flag (no key-off at note end).
    bset    #2,(a0)                     ; Set bit 2 in channel flags.
    bra.w   .parse_track_command        ; Continue.
.handle_stop                            ; Handle $85: Stop music.
    bsr.w   p_turnoff_fn                ; Call turn off function.
    rts                                 ; Exit processing (stops channel?).
.handle_modulation                      ; Handle $81: Set modulation parameters.
    move.b  (a1)+,$42(a0)               ; Read and store modulation delay.
    move.b  (a1)+,$16(a0)               ; Read and store modulation delta (signed?).
    bset    #1,(a0)                     ; Set modulation enable flag (bit 1).
    bra.w   .parse_track_command        ; Continue.
.handle_envelope                        ; Handle $86: Set volume envelope.
    move.b  (a1)+,d0                    ; Read envelope ID.
    lea     envelope_table(pc),a2       ; Load envelope pointer table.
    lsl.w   #2,d0                       ; Multiply by 4 (long pointers).
    move.l  (a2,d0.w),d0                ; Load pointer.
    add.l   a4,d0                       ; Add base offset.
    move.l  d0,$20(a0)                  ; Store as envelope base.
    move.b  (a1)+,$15(a0)               ; Read and store envelope speed or initial index.
    bra.w   .parse_track_command        ; Continue.
.handle_clear_envelope
    move.b  #0,$15(a0)              ; Clear envelope flag/speed
    bra.w   .parse_track_command    ; Continue
.handle_pitch_adjust
    move.b  (a1)+,3(a0)             ; Read and store signed pitch offset
    bra.w   .parse_track_command    ; Continue
.handle_skip
    move.b  (a1)+,d0                ; Read skip count
    bra.w   .parse_track_command    ; Continue (but doesn't advance a1 further? Bug? Or d0 ignored?)
.handle_flag_set
    bset    #3,(a0)                 ; Set bit 3
    bra.w   .parse_track_command    ; Continue
.handle_loop
    movea.l $C(a0),a2               ; Load loop stack pointer into a2
    cmpi.w  #0,$44(a0)              ; Check loop counter
    bne.s   .decrement_loop         ; If non-zero, decrement and loop
.parse_loop_command
    tst.w   (a2)                    ; Test word at stack
    beq.s   .loop_reset             ; If 0, reset to base
    cmpi.w  #1,(a2)                 ; Compare to 1 (new track)
    beq.s   .loop_new_track         ; If equal, init new tune
    cmpi.w  #2,(a2)                 ; Compare to 2 (setup loop)
    beq.s   .loop_setup             ; If equal, setup counter
.advance_loop
    movea.w (a2)+,a1                ; Load offset, advance a2
    adda.l  a4,a1                   ; Add base
    move.l  a2,$C(a0)               ; Update stack pointer
    bra.w   .parse_track_command    ; Continue parsing at new position
.loop_reset
    movea.l 8(a0),a2                ; Reset stack to channel base
    bra.s   .advance_loop           ; Advance
.loop_new_track
    move.w  2(a2),d0                ; Read new track ID
    ext.l   d0                      ; Extend to long
    bsr.w   p_initune_fn            ; Call init tune function
    rts                             ; Exit (starts new track)
.loop_setup
    move.w  2(a2),$44(a0)           ; Read and store loop count
    movea.w -2(a2),a1               ; Load loop position (previous word?)
    adda.l  a4,a1                   ; Add base
    bra.w   .parse_track_command    ; Parse from there
.decrement_loop
    subq.w  #1,$44(a0)              ; Decrement counter
    beq.s   .advance_loop_data      ; If zero, advance past setup
    movea.w -2(a2),a1               ; Else, load loop position
    adda.l  a4,a1                   ; Add base
    bra.w   .parse_track_command    ; Parse
.advance_loop_data
    addq.l  #4,a2                   ; Skip loop setup data (4 bytes)
    bra.s   .parse_loop_command     ; Parse next subcommand
.handle_sound_effect
    move.b  (a1)+,d0                ; Read SFX ID
    movem.l d0-d7/a0-a6,-(sp)       ; Save registers
    bsr.w   p_initfx_fn             ; Call init FX function
    movem.l (sp)+,d0-d7/a0-a6       ; Restore
    bra.w   .parse_track_command    ; Continue
.handle_note
    cmp.b   #$60,d0                 ; Compare to $60 (rest?)
    bne.s   .process_note_frequency ; If not, process as note
    move.w  $26(a0),$10(a0)         ; Set duration counter to base duration (rest)
    move.l  a1,4(a0)                ; Update track position
    move.b  #0,3(a6)                ; Clear key-on in Z80
    move.b  #0,(g_AudioUpdateFlag).l ; Set update flag
    clr.b   $25(a0)                 ; Clear envelope counter or age
    bra.w   .finish_channel         ; Finish channel
.process_note_frequency
    add.b   $24(a0),d0              ; Add instrument octave shift
    add.b   3(a0),d0                ; Add pitch transpose
    move.b  d0,2(a0)                ; Store final note value
    move.l  a1,4(a0)                ; Update track position
    move.w  $26(a0),$10(a0)         ; Set duration counter
    clr.l   d0                      ; Clear d0
    lea     note_frequency_table(pc),a2 ; Load frequency table
    move.b  2(a0),d0                ; Get note
    adda.l  d0,a2                   ; Index table
    move.b  (a2),d2                 ; Read frequency byte
    move.b  d2,5(a6)                ; Store in Z80 slot +5 (coarse freq?)
    move.b  d2,d3                   ; Copy
    andi.b  #7,d2                   ; Mask low 3 bits (fine freq?)
    move.b  d2,$12(a0)              ; Store channel fine freq base
    andi.b  #$38,d3                 ; Mask mid 3 bits (octave?)
    move.b  d3,$14(a0)              ; Store channel octave bits
    lea     note_octave_table(pc),a2 ; Load octave table
    adda.l  d0,a2                   ; Index
    move.b  (a2),d2                 ; Read octave value
    move.b  d2,$13(a0)              ; Store in channel
    move.b  d2,6(a6)                ; Store in Z80 slot +6 (fine freq?)
    move.b  #0,4(a6)                ; Clear Z80 slot +4 (freq update flag?)
    move.b  #0,(g_AudioUpdateFlag).l ; Set update flag
    btst    #2,(a0)                 ; Test sustain flag
    bne.s   .finish_channel         ; If set, no key-on/envelope reset
    move.l  $20(a0),$1C(a0)         ; Reset current envelope pointer to base
    clr.b   $25(a0)                 ; Clear envelope age/counter
    move.b  #1,3(a6)                ; Set key-on flag in Z80
.finish_channel
    addq.b  #1,$25(a0)              ; Increment envelope age
    dbf     d7,.process_channel     ; Decrement channel count, loop if more
.process_sound_effects
    bsr.w   Sound_Process_SFXChannels ; Process SFX channels
    rts                             ; Return
.update_channel_modulation
    clr.w   d1                      ; Clear d1 (modulation accumulator)
    btst    #1,(a0)                 ; Test modulation enable
    beq.s   .check_envelope         ; If not, skip
    subq.b  #1,$42(a0)              ; Decrement mod delay
    bne.s   .apply_modulation       ; If not zero, apply
    bclr    #1,(a0)                 ; Clear mod enable if delay expired
.apply_modulation
    move.b  $16(a0),d1              ; Load mod delta
    ext.w   d1                      ; Sign extend
    add.w   $12(a0),d1              ; Add to fine freq base
    move.w  d1,$12(a0)              ; Store back
    tst.b   $15(a0)                 ; Test envelope flag
    beq.s   .output_frequency       ; If zero, output freq with mod
.check_envelope
    clr.w   d1                      ; Clear d1 (envelope delta)
    move.b  $15(a0),d1              ; Load envelope speed/index
    beq.w   .output_frequency2      ; If zero, no envelope, output
    bpl.s   .apply_envelope         ; If positive, use as multiplier
    move.b  $25(a0),d1              ; If negative, use age shifted
    lsr.b   #1,d1                   ; Halve age for index
.apply_envelope
    movea.l $1C(a0),a2              ; Load current envelope pointer
    move.b  (a2)+,d0                ; Read envelope value, advance
    cmp.b   #$84,d0                 ; Check for loop marker $84
    bne.s   .use_envelope           ; If not, use value
    movea.l $20(a0),a2              ; Reset to envelope base
    move.b  (a2)+,d0                ; Read first value
.use_envelope
    ext.w   d0                      ; Sign extend envelope value
    muls.w  d0,d1                   ; Multiply by index/multiplier
    add.w   $12(a0),d1              ; Add to fine freq (volume envelope affects freq? Wait, likely vibrato envelope)
    move.l  a2,$1C(a0)              ; Update envelope pointer
.output_frequency
    move.w  d1,d3                   ; Copy adjusted fine freq
    lsr.w   #8,d3                   ; Shift high byte (overflow?)
    or.b    $14(a0),d3              ; OR with octave bits
    move.b  d3,5(a6)                ; Store in Z80 coarse freq + octave
    move.b  d1,6(a6)                ; Store low byte in Z80 fine freq
    move.b  #0,4(a6)                ; Clear freq update flag
    move.b  #0,(g_AudioUpdateFlag).l ; Set update flag
.output_frequency2
    bra.w   .finish_channel         ; Finish

; Resets channel volumes to zero and sets update flag.
Sound_ResetChannelVolumes:
    moveq   #0,d1                   ; Clear d1 for zero value
    move.b  d1,(g_Channel0Volume).l ; Reset channel 0 volume
    move.b  d1,(g_Channel1Volume).l ; Reset channel 1 volume
    move.b  d1,(g_Channel2Volume).l ; Reset channel 2 volume
    move.b  d1,(g_Channel3Volume).l ; Reset channel 3 volume
    move.b  d1,(g_Channel4Volume).l ; Reset channel 4 volume
    move.b  d1,(g_Channel5Volume).l ; Reset channel 5 volume
    move.b  #0,(g_AudioUpdateFlag).l ; Set audio update flag
    rts                             ; Return

; VBlank music update function.
p_music_vblank_fn:
    movem.l d0-d7/a0-a6,-(sp)       ; Save all registers
    moveq   #5,d0                   ; Set loop counter for 6 channels
    movea.l #$FFFFFFB6,a1           ; Load address for channel data
    move.b  #$FF,d1                 ; Set value to $FF for muting
.mute_channels
    move.b  d1,(a1)                 ; Mute channel flag
    move.b  d1,3(a1)                ; Mute another byte
    move.b  d1,4(a1)                ; Mute another byte
    move.b  d1,7(a1)                ; Mute another byte
    addq.l  #8,a1                   ; Advance to next channel
    dbf     d0,.mute_channels       ; Loop for all channels
    move.b  #1,(g_AudioUpdateFlag).l ; Set audio update flag to 1
    bsr.w   Sound_UpdateMusicState  ; Update music state
    move.b  (g_AudioUpdateFlag).l,d7 ; Load update flag into d7
    movea.l #$FFFFFFE6,a1           ; Load Z80 write area address
    move.w  #$100,(IO_Z80BUS).l     ; Request Z80 bus
    cmp.b   #1,d7                   ; Check if update flag is 1
    beq.s   .write_z80              ; If yes, write to Z80
    move.w  #$2F,d0                 ; Set copy loop counter ($30 bytes?)
    movea.l #z80_channel_data_buffer_RAM,a0 ; Load source buffer
    movea.l #$FFFFFFB6,a1           ; Load source address
.copy_to_z80
    move.b  (a1)+,(a0)+             ; Copy byte to Z80 buffer
    dbf     d0,.copy_to_z80         ; Loop until done
.write_z80
    cmpi.b  #0,(z80_write_pending).l ; Check if Z80 write is pending
    beq.s   .release_z80            ; If not, release bus
    move.b  (a1)+,(z80_sfx_control_RAM).l ; Write SFX control
    move.b  (a1)+,(z80_SFXParam1).l ; Write param 1
    move.b  (a1)+,(z80_SFXParam2).l ; Write param 2
    move.b  (a1)+,(z80_SFXParam3).l ; Write param 3
    move.b  (a1)+,(z80_SFXParam4).l ; Write param 4
    move.b  (a1)+,(z80_SFXParam5).l ; Write param 5
    move.b  #0,(z80_write_pending).l ; Clear pending flag
    move.b  #0,d7                   ; Clear d7
.release_z80
    move.b  d7,(z80_audio_update_flag).l ; Store update flag in Z80
    move.w  #0,(IO_Z80BUS).l        ; Release Z80 bus
    movem.l (sp)+,d0-d7/a0-a6       ; Restore registers
    rts                             ; Return

; Initializes an SFX channel with given data.
Sound_InitSFXChannel:
    lea     (g_SoundWorkspace).l,a3 ; Load workspace base
    lea     p_music_vblank(pc),a4   ; Load base for PC-relative
    moveq   #0,d0                   ; Clear d0
    move.w  #$48,d0                 ; Channel size
    mulu.w  d7,d0                   ; Compute offset
    lea     6(a3),a0                ; Point to channel base
    adda.l  d0,a0                   ; Add offset
    add.l   a4,d1                   ; Add base to d1 (pointer?)
    move.l  d1,$2C(a0)              ; Store in effect base
    move.l  d1,$28(a0)              ; Store in effect current
    moveq   #0,d1                   ; Clear d1
    move.b  d1,$3C(a0)              ; Clear freq counter
    move.b  d1,$3D(a0)              ; Clear delay counter
    move.b  #4,$3E(a0)              ; Set effect state to 4 (init?)
    rts                             ; Return

; Resets all SFX active flags and channel volumes.
Sound_ResetAllSFX:
    move.b  #0,(g_SFXChannel0ActiveFlag).l ; Clear SFX channel 0 flag
    move.b  #0,(g_SFXChannel1ActiveFlag).l ; Clear SFX channel 1 flag
    move.b  #0,(g_SFXChannel2ActiveFlag).l ; Clear SFX channel 2 flag
    move.b  #0,(g_SFXChannel3ActiveFlag).l ; Clear SFX channel 3 flag
    move.b  #0,(g_SFXChannel4ActiveFlag).l ; Clear SFX channel 4 flag
    move.b  #0,(g_SFXChannel5ActiveFlag).l ; Clear SFX channel 5 flag
    bsr.w   Sound_ResetChannelVolumes ; Reset volumes
    rts                             ; Return

; SFX Initialization Function
p_initfx_fn:
    lea     p_music_vblank(pc),a4   ; Load base for PC-relative
    lea     sfx_pointer_table(pc),a0 ; Load SFX pointer table
    lsl.l   #2,d0                   ; Multiply ID by 4 (long pointers)
    adda.l  d0,a0                   ; Add to table
    movea.l (a0),a0                 ; Load pointer
    adda.l  a4,a0                   ; Add base
    jmp     (a0)                    ; Jump to SFX handler


sfx_pointer_table: 
    dc.l    handle_sfx_siren        ; SFXsiren = 0
    dc.l    handle_sfx_beep1        ; SFXbeep1 = 1
    dc.l    handle_sfx_beep2        ; SFXbeep2 = 2
    dc.l    handle_sfx_id_3         ; SFXcheck2 = 3
    dc.l    handle_sfx_whistle      ; (Unused)
    dc.l    handle_sfx_horn         ; SFXstdef, SFXpuckbody = 5
    dc.l    handle_sfx_pass         ; (Unused)
    dc.l    handle_sfx_shotbh       ; SFXpuckwall1 = 7
    dc.l    handle_sfx_shotfh       ; SFXpuckget, SFXpuckice = 8
    dc.l    handle_sfx_shotwiff     ; SFXpuckpost = 9
    dc.l    handle_sfx_stdef        ; SFXwhistle = 10
    dc.l    handle_sfx_puckget      ; SFXpass = 11
    dc.l    handle_sfx_puckbody     ; SFXshotbh = 12
    dc.l    handle_sfx_puckwall1    ; SFXshotfh = 13
    dc.l    handle_sfx_puckwall2    ; SFXshotwiff = 14
    dc.l    handle_sfx_puckwall3    ; SFXplayerwall = 15
    dc.l    handle_sfx_puckpost     ; (Unused)
    dc.l    handle_sfx_puckice      ; (Unused)
    dc.l    handle_sfx_playerwall   ; (Unused)
    dc.l    handle_sfx_check        ; SFXcheck = 18
    dc.l    handle_sfx_check2       ; (Unused)
    dc.l    handle_sfx_hithigh      ; SFXhithigh = 21
    dc.l    handle_sfx_hitlow       ; SFXhitlow = 23
    dc.l    handle_sfx_id_23        ; SFXhorn = 24
    dc.l    handle_sfx_crowdcheer   ; SFXcrowdcheer = 25
    dc.l    handle_sfx_crowdboo     ; SFXcrowdboo = 26
    dc.l    handle_sfx_oooh         ; (Unused)
    dc.l    handle_sfx_id_27        ; (Unused)
    dc.l    handle_sfx_id_28        ; SFXpuckwall2 = 29
    dc.l    handle_sfx_id_29        ; SFXpuckwall3 = 30
    dc.l    handle_sfx_id_30        ; SFXoooh = 31
    dc.l    handle_sfx_id_31        ; (Unused)
    dc.l    handle_sfx_id_30        ; (Duplicate)
    dc.l    handle_sfx_id_30        ; (Duplicate)
    dc.l    handle_sfx_id_30        ; (Duplicate)

; Processes SFX channels, parsing commands and updating frequency/volume.
Sound_Process_SFXChannels:
    lea     (g_SoundWorkspace).l,a3 ; Load workspace base
    moveq   #5,d7                   ; Set channel count (0-5)
.process_effect_channel
    moveq   #0,d0                   ; Clear d0
    move.w  #$48,d0                 ; Channel size
    mulu.w  d7,d0                   ; Compute offset
    lea     6(a3),a0                ; Point to channel base
    adda.l  d0,a0                   ; Add offset
    movea.l $28(a0),a1              ; Load current effect position
    lea     $1BA(a3),a6             ; Z80 output buffer
    move.w  d7,d0                   ; Copy channel index
    lsl.w   #3,d0                   ; Multiply by 8
    adda.l  d0,a6                   ; Add to buffer pointer
    move.b  $3E(a0),d0              ; Load effect state
    cmp.b   #0,d0                   ; Check if inactive
    beq.w   .next_effect_channel    ; If yes, next channel
    cmp.b   #1,d0                   ; Check if playing
    beq.w   .process_effect         ; If yes, process
    cmp.b   #3,d0                   ; Check if stopping
    bne.s   .stop_effect            ; If not, stop
    move.b  #0,3(a6)                ; Clear key-on
    move.b  #0,(g_AudioUpdateFlag).l ; Set update flag
    move.b  #0,$3E(a0)              ; Set state to inactive
    bra.w   .next_effect_channel    ; Next channel
.stop_effect
    move.b  #0,3(a6)                ; Clear key-on
    move.b  #0,(g_AudioUpdateFlag).l ; Set update flag
    move.b  #1,$3E(a0)              ; Set state to 1 (playing?)
.process_effect
    cmpi.b  #0,$3C(a0)              ; Check freq counter
    bne.w   .update_frequency       ; If set, update freq
    cmpi.b  #0,$3D(a0)              ; Check delay counter
    bne.w   .update_delay           ; If set, update delay
    move.b  #0,$3F(a0)              ; Clear state byte
.parse_effect_command
    moveq   #0,d0                   ; Clear d0
    move.b  (a1)+,d0                ; Read command byte
    cmp.b   #$80,d0                 ; Check for instrument
    beq.w   .effect_instrument      ; Handle instrument
    cmp.b   #$84,d0                 ; Check for stop
    beq.w   .effect_stop            ; Handle stop
    cmp.b   #$83,d0                 ; Check for frequency
    beq.w   .effect_frequency       ; Handle frequency
    cmp.b   #$81,d0                 ; Check for delay
    beq.w   .effect_delay           ; Handle delay
    cmp.b   #$82,d0                 ; Check for alt delay
    beq.w   .effect_alt_delay       ; Handle alt delay
    cmp.b   #$85,d0                 ; Check for loop
    beq.w   .effect_loop            ; Handle loop
    bra.s   .parse_effect_command   ; Continue parsing
.effect_stop
    move.b  #0,3(a6)                ; Clear key-on
    move.b  #0,(g_AudioUpdateFlag).l ; Set update flag
    move.b  #0,$3E(a0)              ; Set inactive
    bra.w   .next_effect_channel    ; Next
.effect_instrument
    move.b  (a1)+,d0                ; Read ID
    cmp.b   $41(a0),d0              ; Compare to current
    beq.s   .effect_output          ; If same, skip
    move.b  d0,$41(a0)              ; Store new ID
    move.l  #$2A5,d1                ; Instrument base
    lsl.w   #5,d0                   ; *32
    add.l   d0,d1                   ; Add offset
    move.w  d1,d0                   ; Copy
    move.b  d0,2(a6)                ; Store low
    lsr.w   #8,d1                   ; High
    move.b  d1,1(a6)                ; Store high
    move.b  #0,(a6)                 ; Clear flag
.effect_output
    move.b  #1,3(a6)                ; Set key-on
    move.b  #0,(g_AudioUpdateFlag).l ; Set update
    bra.w   .parse_effect_command   ; Continue
.effect_frequency
    move.b  (a1)+,d0                ; Read counter
    move.b  d0,$3C(a0)              ; Store freq counter
    move.b  d0,$40(a0)              ; Store initial
    move.l  (a1)+,d0                ; Read freq data
    move.l  d0,$30(a0)              ; Store freq data
    move.l  d0,$34(a0)              ; Store current freq
    move.l  (a1)+,$38(a0)           ; Store increment
    move.l  a1,$28(a0)              ; Update position
    bra.s   .output_effect_frequency ; Output freq
.effect_delay
    move.b  (a1)+,$3D(a0)           ; Store delay
    move.b  #0,$3F(a0)              ; Clear flag
    bra.w   .parse_effect_command   ; Continue
.effect_alt_delay
    move.b  (a1)+,$3D(a0)           ; Store delay
    move.b  #1,$3F(a0)              ; Set flag
    bra.w   .parse_effect_command   ; Continue
.effect_loop
    movea.l $2C(a0),a1              ; Reset to base
    bra.w   .parse_effect_command   ; Continue
.update_delay
    subq.b  #1,$3D(a0)              ; Decrement delay
    move.l  $30(a0),$34(a0)         ; Reset current freq
    move.b  $40(a0),$3C(a0)         ; Reset freq counter
    cmpi.b  #0,$3F(a0)              ; Check flag
    beq.w   .output_effect_frequency ; If zero, output
    move.b  #1,(a6)                 ; Set flag?
    move.b  #0,(g_AudioUpdateFlag).l ; Set update
    bra.w   .output_effect_frequency ; Output
.update_frequency
    move.l  $38(a0),d0              ; Load increment
    add.l   d0,$34(a0)              ; Add to current
    subq.b  #1,$3C(a0)              ; Decrement counter
.output_effect_frequency
    move.l  $34(a0),d0              ; Load current freq
    moveq   #0,d1                   ; Clear d1
.normalize_frequency
    cmp.l   #$7FF,d0                ; Check if > $7FF
    bls.w   .apply_frequency        ; If not, apply
    addi.l  #$800,d1                ; Add to d1
    lsr.l   #1,d0                   ; Halve d0
    bra.s   .normalize_frequency    ; Loop
.apply_frequency
    or.l    d0,d1                   ; OR with d1
    move.l  d1,d0                   ; Copy
    lsr.w   #8,d1                   ; Shift high
    move.b  d1,5(a6)                ; Store coarse
    move.b  d0,6(a6)                ; Store fine
    move.b  #0,4(a6)                ; Clear flag
    move.b  #0,(g_AudioUpdateFlag).l ; Set update
.next_effect_channel
    dbf     d7,.process_effect_channel ; Loop for next channel
    rts                             ; Return

; Writes data to YM2612 registers via Z80.
Sound_WriteYM2612:
    lea     p_music_vblank(pc),a4   ; Load base
    add.l   a4,d1                   ; Add to d1
    move.l  d1,d0                   ; Copy
    ori.w   #$8000,d0               ; Set bit
    move.w  d0,(z80_write_buffer).l ; Store in buffer
    lsr.l   #8,d1                   ; Shift
    lsr.l   #7,d1                   ; Shift
    move.b  d1,(ym2612_reg_part).l  ; Store reg part
    move.b  d1,(ym2612_reg_part).l  ; Store again
    move.b  d2,(ym2612_data_low).l  ; Store data low
    move.b  d3,(ym2612_data_high).l ; Store data high
    move.b  #0,(z80_update_flag).l  ; Clear update flag
    move.b  #1,(z80_write_pending).l ; Set pending
    rts                             ; Return

; Handles puck wall SFX 3.
handle_sfx_puckwall3:
    move.l  #$53BE,d1               ; Load data
    move.b  #$13,d2                 ; Load param
    move.b  #1,d3                   ; Load param
    bsr.s   Sound_WriteYM2612       ; Write to YM2612
    bsr.w   handle_sfx_pass         ; Handle pass SFX
    rts                             ; Return

; Handles SFX ID 3.
handle_sfx_id_3:
    move.l  #fm_instrument_patch_sfx_id_3,d1 ; Load patch
    move.b  #8,d2                   ; Load param
    move.b  #1,d3                   ; Load param
    bsr.s   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Configures YM2612 for reset or stop.
configure_ym2612:
    move.l  #$53BA,d1               ; Load data
    move.b  #$B,d2                  ; Load param
    move.b  #0,d3                   ; Load param
    bsr.s   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles whistle SFX.
handle_sfx_whistle:
    move.l  #fm_instrument_patch_sfx_id_3,d1 ; Load patch
    move.b  #$B,d2                  ; Load param
    move.b  #1,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles puck post SFX.
handle_sfx_puckpost:
    move.l  #$53BE,d1               ; Load data
    move.b  #$18,d2                 ; Load param
    move.b  #1,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    bsr.w   handle_sfx_pass         ; Handle pass
    rts                             ; Return

; Handles puck ice SFX.
handle_sfx_puckice:
    move.l  #$53BE,d1               ; Load data
    move.b  #$10,d2                 ; Load param
    move.b  #1,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    bsr.w   handle_sfx_pass         ; Handle pass
    rts                             ; Return

; Handles player wall SFX.
handle_sfx_playerwall:
    move.l  #$62A0,d1               ; Load data
    move.b  #$10,d2                 ; Load param
    move.b  #1,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles check SFX.
handle_sfx_check:
    move.l  #$62A0,d1               ; Load data
    move.b  #$13,d2                 ; Load param
    move.b  #1,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles check 2 SFX.
handle_sfx_check2:
    move.l  #$62A0,d1               ; Load data
    move.b  #$18,d2                 ; Load param
    move.b  #1,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles puck get SFX.
handle_sfx_puckget:
    move.l  #$4498,d1               ; Load data
    move.b  #$C,d2                  ; Load param
    move.b  #2,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles puck body SFX.
handle_sfx_puckbody:
    move.l  #$3590,d1               ; Load data
    move.b  #$C,d2                  ; Load param
    move.b  #2,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles puck wall 1 SFX.
handle_sfx_puckwall1:
    move.l  #$2776,d1               ; Load data
    move.b  #$B,d2                  ; Load param
    move.b  #2,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles hit high SFX.
handle_sfx_hithigh:
    move.l  #$73E2,d1               ; Load data
    move.b  #$15,d2                 ; Load param
    move.b  #2,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles SFX ID 23.
handle_sfx_id_23:
    move.l  #$73E2,d1               ; Load data
    move.b  #$1F,d2                 ; Load param
    move.b  #2,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles hit low SFX.
handle_sfx_hitlow:
    move.l  #$73E2,d1               ; Load data
    move.b  #$19,d2                 ; Load param
    move.b  #2,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles crowd boo SFX.
handle_sfx_crowdboo:
    move.l  #$793C,d1               ; Load data
    move.b  #$13,d2                 ; Load param
    move.b  #0,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles oooh SFX.
handle_sfx_oooh:
    move.l  #$E2BE,d1               ; Load data
    move.b  #$18,d2                 ; Load param
    move.b  #0,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles SFX ID 31.
handle_sfx_id_31:
    move.l  #fm_instrument_patch_sfx_31,d1 ; Load patch
    move.b  #$1B,d2                 ; Load param
    move.b  #0,d3                   ; Load param
    bsr.w   Sound_WriteYM2612       ; Write to YM2612
    rts                             ; Return

; Handles shot FH SFX.
handle_sfx_shotfh:
    move.l  #$AF0,d1                ; Load pointer
    moveq   #1,d7                   ; Channel 1
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles shot wiff SFX.
handle_sfx_shotwiff:
    move.l  #$B46,d1                ; Load pointer
    moveq   #2,d7                   ; Channel 2
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles horn SFX.
handle_sfx_horn:
    move.l  #$B28,d1                ; Load pointer
    moveq   #1,d7                   ; Channel 1
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles pass SFX.
handle_sfx_pass:
    move.l  #$BDE,d1                ; Load pointer
    moveq   #2,d7                   ; Channel 2
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles shot BH SFX.
handle_sfx_shotbh:
    move.l  #$C38,d1                ; Load pointer
    moveq   #2,d7                   ; Channel 2
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles SFX ID 27.
handle_sfx_id_27:
    move.l  #$BFC,d1                ; Load pointer
    moveq   #2,d7                   ; Channel 2
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles SFX ID 29.
handle_sfx_id_29:
    move.l  #$C56,d1                ; Load pointer
    moveq   #2,d7                   ; Channel 2
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles SFX ID 28.
handle_sfx_id_28:
    move.l  #$C1A,d1                ; Load pointer
    moveq   #2,d7                   ; Channel 2
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles SFX ID 30.
handle_sfx_id_30:
    move.l  #$C74,d1                ; Load pointer
    moveq   #2,d7                   ; Channel 2
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles puck wall 2 SFX.
handle_sfx_puckwall2:
    move.l  #$BC0,d1                ; Load pointer
    moveq   #1,d7                   ; Channel 1
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles crowd cheer SFX.
handle_sfx_crowdcheer:
    move.l  #$B64,d1                ; Load pointer
    moveq   #0,d7                   ; Channel 0
    bsr.w   Sound_InitSFXChannel    ; Init channel
    move.l  #$B8C,d1                ; Load pointer
    moveq   #1,d7                   ; Channel 1
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles stdef SFX.
handle_sfx_stdef:
    move.l  #$B00,d1                ; Load pointer
    moveq   #4,d7                   ; Channel 4
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles beep 1 SFX.
handle_sfx_beep1:
    move.l  #$CA2,d1                ; Load pointer
    moveq   #3,d7                   ; Channel 3
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles beep 2 SFX.
handle_sfx_beep2:
    move.l  #$C92,d1                ; Load pointer
    moveq   #3,d7                   ; Channel 3
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; Handles siren SFX.
handle_sfx_siren:
    move.l  #$AAC,d1                ; Load pointer
    moveq   #0,d7                   ; Channel 0
    bsr.w   Sound_InitSFXChannel    ; Init channel
    move.l  #$AC8,d1                ; Load pointer
    moveq   #1,d7                   ; Channel 1
    bsr.w   Sound_InitSFXChannel    ; Init channel
    rts                             ; Return

; SFX Data: 0xFF74-0x10179
sfx_siren_cmdstream_ch0 ; 0xFF74-0xFF90
    incbin ..\Extracted\Sound\sfx_siren_cmdstream_ch0.bin
sfx_siren_cmdstream_ch1 ; 0xFF90-0xFFB8
    incbin ..\Extracted\Sound\sfx_siren_cmdstream_ch1.bin
sfx_shotfh_cmdstream ; 0xFFB8-0xFFC8
    incbin ..\Extracted\Sound\sfx_shotfh_cmdstream.bin
sfx_stdef_cmdstream ; 0xFFC8-0xFFF0
    incbin ..\Extracted\Sound\sfx_stdef_cmdstream.bin
sfx_horn_cmdstream ; 0xFFF0-0x1000E
    incbin ..\Extracted\Sound\sfx_horn_cmdstream.bin
sfx_shotwiff_cmdstream ; 0x1000E-0x1002C
    incbin ..\Extracted\Sound\sfx_shotwiff_cmdstream.bin
sfx_crowdcheer_cmdstream_ch0 ; 0x1002C-0x10054
    incbin ..\Extracted\Sound\sfx_crowdcheer_cmdstream_ch0.bin
sfx_crowdcheer_cmdstream_ch1 ; 0x10054-0x10088
    incbin ..\Extracted\Sound\sfx_crowdcheer_cmdstream_ch1.bin
sfx_puckwall2_cmdstream ; 0x10088-0x100A6 // there is a stop at 100A0?
    incbin ..\Extracted\Sound\sfx_puckwall2_cmdstream.bin
sfx_pass_cmdstream ; 0x100A6-0x100C4 //puckwall3-2, puckpost-2, puckice-2
    incbin ..\Extracted\Sound\sfx_pass_cmdstream.bin
sfx_id_27_cmdstream ; 0x100C4-0x100E2
    incbin ..\Extracted\Sound\sfx_id_27_cmdstream.bin
sfx_id_28_cmdstream ; 0x100E2-0x10100
    incbin ..\Extracted\Sound\sfx_id_28_cmdstream.bin
sfx_shotbh_cmdstream ; 0x10100-0x1011E
    incbin ..\Extracted\Sound\sfx_shotbh_cmdstream.bin
sfx_id_29_cmdstream ; 0x1011E-0x1013C
    incbin ..\Extracted\Sound\sfx_id_29_cmdstream.bin
sfx_id_30_cmdstream ; 0x1013C-0x1015A
    incbin ..\Extracted\Sound\sfx_id_30_cmdstream.bin
sfx_beep2_cmdstream ; 0x1015A-0x1016A
    incbin ..\Extracted\Sound\sfx_beep2_cmdstream.bin
sfx_beep1_cmdstream ; 0x1016A-0x1017A
    incbin ..\Extracted\Sound\sfx_beep1_cmdstream.bin

note_frequency_table: ;0x1017A-0x101D9
    dcb.b 4,2
    dcb.b 5,3
    dcb.b 3,4
    dcb.b 4,$A
    dcb.b 5,$B
    dcb.b 3,$C
    dcb.b 4,$12
    dcb.b 5,$13
    dcb.b 3,$14
    dcb.b 4,$1A
    dcb.b 5,$1B
    dcb.b 3,$1C
    dcb.b 4,$22
    dcb.b 5,$23
    dcb.b 3,$24
    dcb.b 4,$2A
    dcb.b 5,$2B
    dcb.b 3,$2C
    dcb.b 4,$32
    dcb.b 5,$33
    dcb.b 3,$34
    dcb.b 4,$3A
    dcb.b 5,$3B
    dcb.b 3,$3C

note_octave_table: ;0x101DA-0x10239
    dc.b $84, $AA, $D3, $FE, $2B, $5C, $8F, $C5, $FE, $3B
    dc.b $7B, $C0, $84, $AA, $D3, $FE, $2B, $5C, $8F, $C5
    dc.b $FE, $3B, $7B, $C0, $84, $AA, $D3, $FE, $2B, $5C
    dc.b $8F, $C5, $FE, $3B, $7B, $C0, $84, $AA, $D3, $FE
    dc.b $2B, $5C, $8F, $C5, $FE, $3B, $7B, $C0, $84, $AA
    dc.b $D3, $FE, $2B, $5C, $8F, $C5, $FE, $3B, $7B, $C0
    dc.b $84, $AA, $D3, $FE, $2B, $5C, $8F, $C5, $FE, $3B
    dc.b $7B, $C0, $84, $AA, $D3, $FE, $2B, $5C, $8F, $C5
    dc.b $FE, $3B, $7B, $C0, $84, $AA, $D3, $FE, $2B, $5C
    dc.b $8F, $C5, $FE, $3B, $7B, $C0

envelope_table: ;0x1023A-0x10293
    dc.l envelope0 ; Envelope ID = 0
    dc.l envelope1 ; Envelope ID = 1
    dc.l envelope2 ; Envelope ID = 2
    dc.l envelope3 ; Envelope ID = 3

envelope0:  ; short, subtle vibrato pattern that oscillates gently up and down.
            ; Loops for sustained notes, creating a repeating wobble.
    dc.b $00, $01, $01, $00, $FF, $FE, $FF, $00, $84 ; 0, +1, 0, -1, -2, -1, 0, loop

envelope1:  ; vibrato with a stronger upward peak followed by a downward dip.
            ; Loops for ongoing pitch variation, possibly for whistles or sustained FM tones
    dc.b $00, $01, $02, $02, $02, $01, $FF, $FE, $FE, $FE, $84

envelope2:  ; balanced vibratro with plateaus. Neutral, builds up slightly, holds, dips and holds flat before neutralizing
            ; Pause makes it less constant, useful for breathing effects in crowd cheers or horns
    dc.b $00, $00, $01, $01, $01, $00, $00, $FF, $FF, $FF, $00, $00, $84

envelope3:  ; linear downward ramp starting at neutral and progressively detuning flatter by 1 unit per step, down to -38
            ; creates gradual "sinking" pitch effect. Likely used for dramatic drops in shots, hits, or crowd "oooh" SFX
    dc.b $00, $FF, $FE, $FD, $FC, $FB, $FA, $F9, $F8, $F7, $F6, $F5, $F4, $F3
    dc.b $F2, $F1, $F0, $EF, $EE, $ED, $EC, $EB, $EA, $E9, $E8, $E7, $E6, $E5
    dc.b $E4, $E3, $E2, $E1, $E0, $DF, $DE, $DD, $DC, $DB, $DA, $84, $06

fmtune_pointer_table: ;0x10294-0x10315 | Bytes 0-1 = Num Tracks-1, Bytes 2-3: Tempo
	dc.w $0507
	dc.l fmtune_song0_ch0 - p_music_vblank
	dc.l fmtune_song0_ch1 - p_music_vblank
	dc.l fmtune_song0_ch2 - p_music_vblank
	dc.l fmtune_song0_ch3 - p_music_vblank
	dc.l fmtune_song0_ch4 - p_music_vblank
	dc.l fmtune_song0_ch5 - p_music_vblank	; SngEOP

	dc.w $0506
	dc.l fmtune_song1_ch0 - p_music_vblank
	dc.l fmtune_song1_ch1 - p_music_vblank
	dc.l fmtune_song1_ch2 - p_music_vblank
	dc.l fmtune_song1_ch3 - p_music_vblank
	dc.l fmtune_song1_ch4 - p_music_vblank
	dc.l fmtune_song1_ch5 - p_music_vblank	; SngTitle

	dc.w $0506
	dc.l fmtune_song2_ch0 - p_music_vblank
	dc.l fmtune_song2_ch1 - p_music_vblank
	dc.l fmtune_song2_ch2 - p_music_vblank
	dc.l fmtune_song2_ch3 - p_music_vblank
	dc.l fmtune_song2_ch4 - p_music_vblank
	dc.l fmtune_song2_ch5 - p_music_vblank	; SngTitle Reprise

	dc.w $0506
	dc.l fmtune_song3_ch0 - p_music_vblank
	dc.l fmtune_song3_ch1 - p_music_vblank
	dc.l fmtune_song3_ch2 - p_music_vblank
	dc.l fmtune_song3_ch3 - p_music_vblank
	dc.l fmtune_song3_ch4 - p_music_vblank
	dc.l fmtune_song3_ch5 - p_music_vblank	; SngEOG

	dc.w $0507
	dc.l fmtune_song4_ch0 - p_music_vblank
	dc.l fmtune_song4_ch1 - p_music_vblank
	dc.l fmtune_song4_ch2 - p_music_vblank
	dc.l fmtune_song4_ch3 - p_music_vblank
	dc.l fmtune_song4_ch4 - p_music_vblank
	dc.l fmtune_song4_ch5 - p_music_vblank	; SngPO

fmtune_song4_ch0: ; 0x10316-0x1031F
    dc.w $11A3, $0002, $0003, $1A41, $0000

fmtune_song4_ch1: ; 0x10320-0x1032D
    dc.w $118B, $11C7, $0002, $0003, $116D, $1CA5, $0000

fmtune_song4_ch2: ; 0x1032E-0x1033B
    dc.w $118B, $11F0, $0002, $0003, $116D, $1D00, $0000

fmtune_song4_ch3: ; 0x1033C-0x1034B
    dc.w $116D, $1219, $1275, $118E, $1219, $1275, $12DE, $0000

fmtune_song4_ch4: ; 0x1034C-0x1035B
    dc.w $116D, $1247, $12A8, $118E, $1247, $12A8, $133F, $0000

fmtune_song4_ch5: ; 0x1035C-0x1035F
    dc.w $1C35, $0000

fmtune_song3_ch0: ; 0x10360-0x10367
    dc.w $1A41, $0002, $0003, $0000

fmtune_song3_ch1: ; 0x10368-0x10371
    dc.w $116D, $1CA5, $0002, $0003, $0000

fmtune_song3_ch3: ; 0x10372-0x1037B
    dc.w $116D, $1D00, $0002, $0003, $0000

fmtune_song3_ch2: ; 0x1037C-0x103A9
    dc.w $116D, $13A0, $118E, $13A0, $1547, $1547, $13D5, $140E
    dc.w $0002, $0003, $13D5, $116D, $141E, $118E, $13EF, $141E
    dc.w $13EF, $116D, $18D5, $18D5, $1649, $1649, $0000

fmtune_song3_ch4: ; 0x103AA-0x103DD
    dc.w $118E, $14CD, $14CD, $156C, $156C, $1502, $119A, $1537
    dc.w $0002, $0003, $118E, $1502, $118E, $1477, $118E, $1518
    dc.w $118E, $1477, $119A, $1518, $116D, $198B, $198B, $1855
    dc.w $1855, $0000

fmtune_song3_ch5: ; 0x103DE-0x1040D
    dc.w $1C35, $0002, $0006, $1D98, $1C35, $1C4E, $1C35, $1C35
    dc.w $1C35, $1C4E, $1C35, $1D98, $1C35, $0002, $0005, $1C65
    dc.w $1C35, $1C4E, $1C8D, $1C35, $1C8D, $1D98, $1C65, $0000

fmtune_song1_ch0: ; 0x1040E-0x10425
    dc.w $118B, $1ED6, $1EF0, $1A87, $1ACB, $1A87, $1A41
    dc.w $0002, $0005, $1591, $0001, $0002

fmtune_song2_ch0: ; 0x10426-0x1042D
    dc.w $1A41, $0002, $0003, $0000

fmtune_song1_ch1: ; 0x1042E-0x10445
    dc.w $116D, $1EE3, $1EE3, $1BF1, $1CA5, $1BF1, $116D, $1CA5
    dc.w $0002, $0005, $116D, $160A

fmtune_song2_ch1: ; 0x10446-0x1044D
    dc.w $1CA5, $0002, $0003, $0000

fmtune_song1_ch3: ; 0x1044E-0x10467
    dc.w $118B, $1EE3, $1EE3, $116D, $1BAD, $1D00, $1BAD, $116D
    dc.w $1D00, $0002, $0005, $118B, $160A

fmtune_song2_ch3: ; 0x10468-0x10471
    dc.w $116D, $1D00, $0002, $0003, $0000

fmtune_song1_ch2: ; 0x10472-0x10497
    dc.w $118E, $1F42, $1F42, $116D, $1B1D, $118B, $1649, $118E
    dc.w $1B1D, $118B, $1649, $116D, $1649, $1649, $1649, $16BD
    dc.w $16BD, $116D, $15B0

fmtune_song2_ch2: ; 0x10498-0x104A3
    dc.w $116D, $18D5, $18D5, $1649, $1649
    dc.w $0000

fmtune_song1_ch4: ; 0x104A4-0x104C5
    dc.w $11A0, $1F42, $1F42, $116D, $1156, $1156, $1B6A
    dc.w $116D, $17EF, $116D, $17EF, $17EF, $1855, $1756, $1756
    dc.w $116D, $15DE
    

fmtune_song2_ch4: ; 0x104C6-0x104D1
    dc.w $116D, $198B, $198B, $1855, $1855, $0000

fmtune_song1_ch5: ; 0x104D2-0x10537
    dc.w $1DC4, $0002, $0006, $1DD2
    dc.w $1B0D, $0002, $0007, $1B0D, $0002, $0006
    dc.w $1D98, $1B0D, $0002, $0006, $1D98, $1B0D, $0002, $0006
    dc.w $1D98, $1C35, $1C4E, $1C35, $1C35, $1C35, $1C4E, $1C35
    dc.w $1D98, $1C35, $0002, $0006, $1D98, $1C35, $1C4E, $1C35
    dc.w $1C35, $1C35, $1C4E, $1C35, $1D98, $1C35, $0002, $0005
    dc.w $1C65, $1C35, $1C4E, $1C8D, $1C35, $1C8D, $1D98, $1C65
    dc.w $1624

fmtune_song2_ch5: ; 0x10538-0x10567
    dc.w $1C35, $0002, $0006
    dc.w $1D98, $1C35, $1C4E, $1C35, $1C35, $1C35, $1C4E, $1C35
    dc.w $1D98, $1C35, $0002, $0005, $1C65, $1C35, $1C4E, $1C8D
    dc.w $1C35, $1C8D, $1D98, $1C65, $0000

fmtune_song0_ch0: ; 0x10568-0x1057F
    dc.w $1ED6, $1EF0, $1D5B, $1D5B, $1D5B, $1D5B, $1D5B, $1D5B
    dc.w $1D5B, $1D5B, $1F83, $0000

fmtune_song0_ch1: ; 0x10580-0x1059B
    dc.w $116D, $1EE3, $1EE3, $118B, $1DE7, $1DE7, $1DE7, $1DE7, $1DE7, $1DE7, $1DE7
    dc.w $1DE7, $1FC9, $0000
    

fmtune_song0_ch3: ; 0x1059C-0x105B5
    dc.w $118B, $1EE3, $1EE3, $1DFA, $1DFA
    dc.w $1DFA, $1DFA, $1DFA, $1DFA, $1DFA, $1DFA, $200C, $0000

fmtune_song0_ch2: ; 0x105B6-0x105C9
    dc.w $118E, $1F42
    dc.w $119A, $1F42, $116D, $1E0D
    dc.w $1E0D, $116D, $204F, $0000
    
fmtune_song0_ch4: ; 0x105CA-0x105DF
    dc.w $11A0, $1F42, $119D, $1F42, $116D, $1E73, $118E, $1E73, $116D, $20D5, $0000

    

fmtune_song0_ch5: ; 0x105E0-0x11624
    dc.w $1DC4, $0002, $0006, $1DD2
    dc.w $1D6D, $0002, $0007
    dc.w $1D6D, $1D6D, $1D6D, $1DA9, $1D6D, $1D6D, $1D6D, $1DA9
    dc.w $1D6D, $1D6D, $1D6D, $1D83, $1D6D, $1D6D
    dc.w $1D6D, $1D98, $0000, $C060, $8480, $00B0, $6084, $8000
    dc.w $C060, $6084

; Sequence data in 68k assembly format
fmtune_seq0: ; 0x1061E - 0x1061F
    dc.b $80, $00

fmtune_seq1: ; 0x10620 - 0x10623
    dc.b $C0, $60, $60, $60

fmtune_seq2: ; 0x10624 - 0x10627
    dc.b $60, $84, $88, $FF

fmtune_seq3: ; 0x10628 - 0x1062B
    dc.b $84, $88, $FE, $84

fmtune_seq4: ; 0x1062C - 0x1064F
    dc.b $88, $03, $84, $88, $FB, $84, $88, $05
    dc.b $84, $88, $0C, $84, $88, $07, $84, $88
    dc.b $06, $84, $88, $01, $84, $88, $08, $84
    dc.b $88, $0A, $84, $88, $FB, $84, $88, $F4
    dc.b $84, $88, $0E, $84

fmtune_seq5: ; 0x10650 - 0x1067F
    dc.b $88, $02, $84, $88
    dc.b $00, $84, $88, $18, $84, $88, $E8, $84
    dc.b $88, $DC, $84, $88, $11, $84, $88, $24
    dc.b $84, $88, $1F, $84, $88, $13, $84

    dc.b $80, $01, $A2, $1F, $1F, $1F, $1F, $1F
    dc.b $1F, $26, $29, $22, $22, $25, $26, $22
    dc.b $22, $1A, $1C, $1D, $1D

fmtune_seq6: ; 0x10680 - 0x106AF
    dc.b $1D, $1D, $1D
    dc.b $1D, $21, $22, $24, $24, $24, $24, $26
    dc.b $26, $1D, $1E, $84

    dc.b $80, $11, $A4, $37, $A2, $60, $37, $A4
    dc.b $37, $60, $A2, $60, $A4, $35, $A2, $35
    dc.b $A2, $35, $60, $35, $60, $A4, $35, $A2
    dc.b $60, $35, $A4, $35, $60, $A2, $60, $A4
    dc.b $37

fmtune_seq7: ; 0x106B0 - 0x106DF
    dc.b $A2, $37, $A2, $37, $60, $37, $60, $84
    dc.b $80, $11, $A4, $32, $A2, $60, $32, $A4
    dc.b $32, $60, $A2, $60, $A4, $2E, $A2, $2E
    dc.b $A2, $2E, $60, $2E, $60, $A4, $30, $A2
    dc.b $60, $30, $A4, $30, $60, $A2, $60, $A4
    dc.b $30, $A2, $30, $A2, $32, $60, $32, $60

fmtune_seq8: ; 0x106E0 - 0x106EF
    dc.b $84, $80, $15, $86, $01, $80, $A2, $60
    dc.b $32, $35, $A8, $37, $A2, $81, $09, $0B

fmtune_seq9: ; 0x106F0 - 0x1071F
    dc.b $35, $60, $81, $09, $0B, $35, $AC, $35
    dc.b $A2, $60, $30, $32, $A8, $35, $A2, $81
    dc.b $08, $0E, $37, $60, $81, $08, $0E, $37
    dc.b $37, $60, $37, $60, $37, $60, $84, $80
    dc.b $15, $86, $00, $80, $A2, $60, $2F, $30
    dc.b $A8, $32, $A2, $81, $09, $0B, $30, $60

fmtune_seq10: ; 0x10720 - 0x1074F
    dc.b $81, $09, $0B, $30, $AC, $32, $A2, $60
    dc.b $2D, $2E, $A8, $30, $A2, $81, $08, $06
    dc.b $34, $60, $81, $08, $06, $34, $34, $60
    dc.b $34, $60, $34, $60, $84, $A2, $60, $32
    dc.b $35, $37, $60, $37, $3A, $81, $09, $04
    dc.b $3E, $60, $81, $09, $04, $3E, $A8, $3E

fmtune_seq11: ; 0x10750 - 0x1077F
    dc.b $A2, $60, $81, $09, $08, $3C, $60, $81
    dc.b $09, $08, $3C, $3C, $60, $81, $09, $07
    dc.b $39, $60, $39, $3C, $60, $3C, $3C, $60
    dc.b $3C, $60, $A4, $81, $09, $0E, $39, $84
    dc.b $A2, $60, $2F, $30, $32, $60, $32, $35
    dc.b $81, $09, $0B, $35, $60, $81, $09, $0B
fmtune_seq12: ; 0x10780 - 0x107AF
    dc.b $35, $A8, $35, $A2, $60, $81, $09, $07
    dc.b $39, $60, $81, $09, $07, $39, $39, $60
    dc.b $81, $09, $0B, $35, $60, $35, $39, $60
    dc.b $81, $09, $0B, $37, $81, $09, $0B, $37
    dc.b $60, $37, $60, $A4, $37, $84, $80, $12
    dc.b $A2, $60, $34, $37, $A6, $39, $A2, $60
fmtune_seq13: ; 0x107B0 - 0x107DF
    dc.b $A4, $81, $09, $06, $36, $A2, $36, $32
    dc.b $AA, $2D, $A2, $60, $34, $37, $A6, $39
    dc.b $A2, $60, $A4, $81, $09, $06, $36, $A2
    dc.b $39, $39, $60, $81, $0A, $0B, $37, $60
    dc.b $A2, $81, $0A, $0B, $37, $39, $A2, $60
    dc.b $34, $37, $A6, $39, $A2, $60, $A4, $81
fmtune_seq14: ; 0x107E0 - 0x1080F
    dc.b $09, $06, $36, $A2, $36, $32, $AA, $2D
    dc.b $A2, $60, $32, $32, $60, $32, $32, $60
    dc.b $81, $08, $0B, $32, $60, $81, $08, $0B
    dc.b $32, $81, $08, $0B, $32, $32, $A2, $81
    dc.b $08, $05, $33, $33, $32, $30, $84, $80
    dc.b $12, $A2, $60, $30, $32, $A6, $34, $A2
fmtune_seq15: ; 0x10810 - 0x1083F
    dc.b $60, $A4, $81, $09, $09, $32, $A2, $32
    dc.b $2D, $AA, $2A, $A2, $60, $30, $32, $A6
    dc.b $34, $A2, $60, $A4, $81, $09, $09, $32
    dc.b $A2, $34, $34, $60, $81, $0A, $0B, $32
    dc.b $60, $A2, $81, $0A, $0B, $32, $34, $A2
    dc.b $60, $30, $32, $A6, $34, $A2, $60, $A4
fmtune_seq16: ; 0x10840 - 0x1086F
    dc.b $81, $09, $09, $32, $A2, $32, $2D, $AA
    dc.b $2A, $A2, $60, $2F, $2F, $60, $2F, $2F
    dc.b $60, $81, $08, $0B, $2D, $60, $81, $08
    dc.b $0B, $2D, $81, $08, $0B, $2D, $2F, $A2
    dc.b $81, $08, $04, $30, $30, $2F, $2D, $84
    dc.b $80, $12, $86, $00, $80, $A2, $60, $A2
fmtune_seq17: ; 0x10870 - 0x1089F
    dc.b $37, $37, $60, $37, $37, $60, $A4, $81
    dc.b $09, $06, $36, $A2, $36, $32, $AA, $2D
    dc.b $A2, $60, $A2, $37, $37, $60, $37, $37
    dc.b $60, $A4, $81, $09, $06, $36, $A2, $39
    dc.b $39, $60, $81, $0A, $0B, $37, $60, $A2
    dc.b $81, $0A, $0B, $37, $39, $A2, $60, $A2
fmtune_seq18: ; 0x108A0 - 0x108CF
    dc.b $37, $37, $60, $37, $37, $60, $A4, $81
    dc.b $09, $06, $36, $A2, $36, $32, $A4, $2D
    dc.b $A2, $2D, $A1, $30, $32, $30, $2D, $A2
    dc.b $60, $32, $32, $60, $32, $32, $60, $81
    dc.b $08, $0B, $32, $60, $81, $08, $0B, $32
    dc.b $81, $08, $0B, $32, $32, $A2, $81, $08
fmtune_seq19: ; 0x108D0 - 0x108FF
    dc.b $05, $33, $33, $32, $30, $84, $A2, $81
    dc.b $0C, $04, $36, $36, $34, $30, $81, $08
    dc.b $05, $33, $33, $32, $30, $84, $86, $00
    dc.b $80, $A2, $34, $AE, $81, $0A, $0F, $37
    dc.b $A2, $60, $37, $A4, $81, $08, $0B, $32
    dc.b $A2, $81, $08, $05, $32, $A1, $32, $30
fmtune_seq20: ; 0x10900 - 0x1092F
    dc.b $A2, $32, $A1, $30, $A3, $2D, $A2, $2D
    dc.b $34, $A8, $81, $0E, $0B, $37, $A4, $81
    dc.b $0A, $08, $32, $A2, $34, $39, $60, $A4
    dc.b $81, $0A, $09, $37, $A2, $37, $36, $A4
    dc.b $60, $A2, $34, $AA, $81, $0A, $0F, $37
    dc.b $A2, $81, $08, $0B, $32, $81, $08, $0B
fmtune_seq21: ; 0x10930 - 0x1095F
    dc.b $32, $A2, $81, $08, $05, $32, $A1, $32
    dc.b $30, $A4, $32, $A2, $30, $2D, $84, $A2
    dc.b $30, $AE, $81, $0A, $10, $30, $A2, $60
    dc.b $34, $A4, $81, $08, $09, $2F, $A2, $81
    dc.b $08, $09, $2F, $A1, $2F, $2D, $A2, $2F
    dc.b $A1, $2D, $A3, $28, $A2, $28, $30, $A8
fmtune_seq22: ; 0x10960 - 0x1098F
    dc.b $81, $0A, $10, $30, $A4, $81, $0A, $07
    dc.b $2F, $A2, $30, $34, $60, $A4, $81, $0A
    dc.b $09, $32, $A2, $34, $32, $A4, $60, $A2
    dc.b $30, $AA, $81, $0A, $10, $30, $A2, $81
    dc.b $08, $09, $2F, $81, $08, $09, $2F, $A2
    dc.b $81, $08, $09, $2F, $A1, $2F, $2D, $A4
fmtune_seq23: ; 0x10990 - 0x109BF
    dc.b $2F, $A2, $2D, $28, $84, $80, $12, $86
    dc.b $01, $80, $A2, $60, $A2, $34, $34, $60
    dc.b $34, $34, $60, $A4, $81, $09, $09, $32
    dc.b $A2, $32, $2D, $AA, $2A, $A2, $60, $A2
    dc.b $34, $34, $60, $34, $34, $60, $A4, $81
    dc.b $09, $09, $32, $A2, $34, $34, $60, $81
fmtune_seq24: ; 0x109C0 - 0x109EF
    dc.b $0A, $0B, $32, $60, $A2, $81, $0A, $0B
    dc.b $32, $34, $A2, $60, $A2, $34, $34, $60
    dc.b $34, $34, $60, $A4, $81, $09, $09, $32
    dc.b $A2, $32, $2D, $AA, $81, $12, $09, $30
    dc.b $A2, $60, $2F, $2F, $60, $2F, $2F, $60
    dc.b $81, $08, $0B, $2D, $60, $81, $08, $0B
fmtune_seq25: ; 0x109F0 - 0x10A1F
    dc.b $2D, $81, $08, $0B, $2D, $2F, $A2, $81
    dc.b $08, $04, $30, $30, $2F, $2D, $84, $A2
    dc.b $81, $0C, $03, $32, $32, $30, $2D, $81
    dc.b $08, $04, $30, $30, $2F, $2D, $84, $A2
    dc.b $60, $81, $0A, $07, $3B, $81, $0A, $07
    dc.b $3B, $60, $81, $0A, $07, $3B, $81, $0A
fmtune_seq26: ; 0x10A20 - 0x10A4F
    dc.b $07, $3B, $60, $A4, $81, $0A, $07, $3B
    dc.b $A2, $3B, $39, $36, $81, $0A, $0B, $37
    dc.b $60, $39, $39, $84, $A2, $60, $81, $0A
    dc.b $0B, $37, $81, $0A, $0B, $37, $60, $81
    dc.b $0A, $0B, $37, $81, $0A, $0B, $37, $60
    dc.b $A4, $81, $0A, $0B, $37, $A2, $37, $36
fmtune_seq27: ; 0x10A50 - 0x10A7F
    dc.b $32, $81, $0A, $08, $32, $60, $34, $34
    dc.b $84, $80, $01, $A4, $21, $A2, $60, $A4
    dc.b $21, $A2, $60, $A4, $21, $A2, $60, $A4
    dc.b $21, $A2, $60, $A4, $21, $60, $E0, $21
    dc.b $B4, $60, $AC, $81, $48, $FD, $28, $84
    dc.b $86, $00, $80, $80, $12, $A4, $81, $0C
fmtune_seq28: ; 0x10A80 - 0x10AAF
    dc.b $09, $43, $A2, $60, $A4, $81, $0C, $09
    dc.b $43, $A2, $60, $A4, $81, $0C, $09, $43
    dc.b $A2, $60, $A4, $81, $0C, $09, $43, $A2
    dc.b $60, $A4, $81, $0C, $09, $43, $60, $80
    dc.b $05, $C0, $15, $60, $60, $84, $80, $12
    dc.b $86, $00, $80, $A4, $81, $0C, $07, $3E
fmtune_seq29: ; 0x10AB0 - 0x10ADF
    dc.b $A2, $60, $A4, $81, $0C, $07, $3E, $A2
    dc.b $60, $A4, $81, $0C, $07, $3E, $A2, $60
    dc.b $A4, $81, $0C, $07, $3E, $A2, $60, $A4
    dc.b $81, $0C, $07, $3E, $60, $E0, $60, $C0
    dc.b $60, $84, $80, $05, $A4, $2D, $A2, $60
    dc.b $A4, $2D, $A2, $60, $A4, $2D, $A2, $60
fmtune_seq30: ; 0x10AE0 - 0x10B0F
    dc.b $A4, $2D, $A2, $60, $A4, $2D, $60, $E0
    dc.b $2D, $C0, $60, $84, $80, $04, $A4, $15
    dc.b $A2, $60, $A4, $15, $A2, $60, $A4, $15
    dc.b $A2, $60, $A4, $15, $A2, $60, $A4, $15
    dc.b $60, $C0, $15, $C0, $60, $B8, $60, $A2
    dc.b $80, $04, $15, $15, $15, $A1, $15, $15
fmtune_seq31: ; 0x10B10 - 0x10B3F
    dc.b $84, $80, $12, $86, $00, $80, $A6, $81
    dc.b $0A, $0A, $40, $AA, $81, $0A, $08, $3E
    dc.b $A4, $60, $A2, $3E, $60, $3E, $A4, $81
    dc.b $0A, $08, $3E, $A2, $60, $A6, $81, $0A
    dc.b $0A, $40, $AA, $81, $0A, $08, $3E, $A2
    dc.b $60, $81, $0C, $04, $42, $42, $40, $81
fmtune_seq32: ; 0x10B40 - 0x10B6F
    dc.b $0C, $04, $42, $42, $40, $3C, $A6, $81
    dc.b $0B, $09, $40, $AA, $81, $0C, $07, $3E
    dc.b $A4, $60, $A2, $3E, $60, $3E, $A4, $81
    dc.b $0A, $08, $3E, $A2, $60, $A2, $60, $81
    dc.b $0B, $08, $3E, $3E, $3B, $3E, $A4, $81
    dc.b $09, $09, $3E, $A2, $81, $09, $09, $3E
fmtune_seq33: ; 0x10B70 - 0x10B9F
    dc.b $60, $81, $09, $09, $3E, $3E, $3B, $81
    dc.b $09, $07, $39, $A1, $39, $37, $A2, $81
    dc.b $09, $0D, $37, $37, $84, $80, $12, $86
    dc.b $00, $80, $A2, $81, $0A, $0A, $40, $A4
    dc.b $81, $0E, $07, $40, $A3, $81, $0A, $08
    dc.b $3E, $A1, $43, $42, $40, $42, $43, $42
fmtune_seq34: ; 0x10BA0 - 0x10BCF
    dc.b $40, $A4, $81, $0A, $0A, $40, $A2, $3E
    dc.b $60, $3E, $A4, $81, $0A, $08, $3E, $A2
    dc.b $40, $A2, $81, $0A, $0A, $40, $A4, $81
    dc.b $0E, $07, $40, $A3, $81, $0A, $08, $3E
    dc.b $A1, $39, $3C, $3E, $3F, $40, $43, $45
    dc.b $A6, $81, $12, $0B, $45, $81, $12, $04
fmtune_seq35: ; 0x10BD0 - 0x10BFF
    dc.b $48, $A4, $81, $12, $04, $48, $A2, $81
    dc.b $0A, $0A, $40, $A4, $81, $0E, $07, $40
    dc.b $A3, $81, $0A, $08, $3E, $A1, $43, $42
    dc.b $40, $42, $43, $42, $40, $A4, $81, $0A
    dc.b $0A, $40, $A2, $3E, $60, $3E, $A4, $81
    dc.b $0A, $08, $3E, $A2, $40, $A2, $60, $A6
fmtune_seq36: ; 0x10C00 - 0x10C2F
    dc.b $81, $12, $07, $3D, $81, $12, $07, $3D
    dc.b $A4, $81, $12, $04, $3E, $A2, $40, $A4
    dc.b $81, $12, $0B, $3D, $A1, $3E, $40, $3E
    dc.b $3B, $3E, $40, $3E, $3B, $84, $80, $12
    dc.b $86, $01, $80, $A2, $81, $0A, $07, $3C
    dc.b $A4, $81, $0E, $05, $3C, $A3, $81, $0A
fmtune_seq37: ; 0x10C30 - 0x10C5F
    dc.b $0E, $3B, $A1, $3F, $3E, $3C, $3E, $3F
    dc.b $3E, $3C, $A4, $81, $0A, $07, $3C, $A2
    dc.b $39, $60, $39, $A4, $81, $0A, $0D, $39
    dc.b $A2, $3B, $A2, $81, $0A, $07, $3C, $A4
    dc.b $81, $0E, $05, $3C, $A3, $81, $0A, $0E
    dc.b $3B, $A1, $34, $39, $3B, $3C, $3D, $40
fmtune_seq38: ; 0x10C60 - 0x10C8F
    dc.b $42, $A6, $81, $12, $09, $42, $81, $12
    dc.b $06, $43, $A4, $81, $12, $06, $43, $A2
    dc.b $81, $0A, $07, $3C, $A4, $81, $0E, $05
    dc.b $3C, $A3, $81, $0A, $0E, $3B, $A1, $3F
    dc.b $3E, $3C, $3E, $3F, $3E, $3C, $A4, $81
    dc.b $0A, $07, $3C, $A2, $39, $60, $39, $A4
fmtune_seq39: ; 0x10C90 - 0x10CBF
    dc.b $81, $0A, $0D, $39, $A2, $3B, $A2, $60
    dc.b $A6, $81, $12, $07, $39, $81, $12, $07
    dc.b $39, $A4, $81, $12, $07, $39, $A2, $3B
    dc.b $A4, $81, $12, $07, $39, $A1, $42, $43
    dc.b $42, $40, $42, $43, $42, $40, $84, $80
    dc.b $12, $86, $00, $80, $A6, $81, $0E, $05
fmtune_seq40: ; 0x10CC0 - 0x10CEF
    dc.b $3C, $AA, $81, $0E, $0A, $3B, $A4, $60
    dc.b $A2, $39, $60, $39, $A4, $81, $0A, $0D
    dc.b $39, $A2, $60, $A6, $81, $0E, $05, $3C
    dc.b $AA, $81, $0E, $0A, $3B, $A2, $60, $81
    dc.b $0C, $03, $3E, $3E, $3C, $81, $0C, $03
    dc.b $3E, $3E, $3C, $39, $A6, $81, $0E, $05
fmtune_seq41: ; 0x10CF0 - 0x10D1F
    dc.b $3C, $AA, $81, $0E, $0A, $3B, $A4, $60
    dc.b $A2, $39, $60, $39, $A4, $81, $0A, $0D
    dc.b $39, $A2, $60, $A2, $60, $A6, $81, $14
    dc.b $06, $39, $81, $14, $06, $39, $AA, $81
    dc.b $0C, $0D, $3C, $A4, $81, $0C, $0A, $3D
    dc.b $81, $0C, $07, $3E, $84, $80, $12, $86
fmtune_seq42: ; 0x10D20 - 0x10D4F
    dc.b $00, $80, $A6, $81, $0E, $08, $43, $A6
    dc.b $81, $0E, $08, $43, $A1, $43, $45, $43
    dc.b $40, $A4, $81, $0E, $08, $43, $A2, $42
    dc.b $60, $42, $A4, $81, $0A, $05, $42, $A2
    dc.b $60, $A6, $81, $0E, $08, $43, $A6, $81
    dc.b $0E, $08, $43, $A1, $43, $45, $43, $40
fmtune_seq43: ; 0x10D50 - 0x10D7F
    dc.b $A2, $81, $0E, $08, $43, $A6, $81, $0E
    dc.b $08, $43, $A4, $81, $0E, $08, $43, $81
    dc.b $0E, $08, $43, $A6, $81, $0E, $08, $43
    dc.b $A6, $81, $0E, $08, $43, $A8, $81, $17
    dc.b $07, $42, $A2, $45, $60, $45, $A4, $81
    dc.b $0A, $0B, $43, $A2, $60, $A4, $60, $A1
fmtune_seq44: ; 0x10D80 - 0x10DAF
    dc.b $40, $43, $40, $43, $40, $43, $40, $43
    dc.b $40, $43, $40, $43, $40, $43, $40, $43
    dc.b $40, $43, $40, $43, $3F, $42, $3E, $41
    dc.b $3D, $40, $3C, $3F, $84, $80, $12, $86
    dc.b $00, $80, $A1, $40, $43, $45, $43, $A2
    dc.b $81, $08, $0E, $43, $A1, $40, $43, $45
fmtune_seq45: ; 0x10DB0 - 0x10DDF
    dc.b $43, $A2, $81, $08, $0E, $43, $A1, $40
    dc.b $43, $45, $43, $A2, $81, $08, $0E, $43
    dc.b $A1, $40, $43, $45, $43, $A2, $81, $08
    dc.b $0E, $43, $A1, $40, $43, $45, $43, $45
    dc.b $43, $45, $47, $A2, $81, $06, $0C, $47
    dc.b $81, $06, $0C, $47, $A4, $81, $08, $10
fmtune_seq46: ; 0x10DE0 - 0x10E0F
    dc.b $45, $81, $08, $0E, $43, $81, $08, $06
    dc.b $42, $A2, $81, $06, $09, $42, $81, $06
    dc.b $09, $42, $A4, $42, $A2, $81, $06, $07
    dc.b $3F, $3F, $3E, $3C, $A1, $40, $43, $45
    dc.b $43, $A2, $81, $08, $0E, $43, $A1, $40
    dc.b $43, $45, $43, $A2, $81, $08, $0E, $43
fmtune_seq47: ; 0x10E10 - 0x10E3F
    dc.b $A1, $40, $43, $45, $43, $A2, $81, $08
    dc.b $0E, $43, $A1, $40, $43, $45, $43, $A2
    dc.b $81, $08, $0E, $43, $A1, $40, $43, $45
    dc.b $43, $45, $43, $45, $47, $A2, $81, $0A
    dc.b $0D, $45, $A4, $4A, $A2, $81, $0A, $0D
    dc.b $45, $A4, $4A, $A2, $81, $0A, $0D, $45
fmtune_seq48: ; 0x10E40 - 0x10E6F
    dc.b $A4, $4A, $A2, $81, $0A, $0D, $45, $A4
    dc.b $4A, $A4, $81, $0A, $08, $4A, $81, $0A
    dc.b $08, $4A, $84, $80, $12, $86, $00, $80
    dc.b $A1, $3C, $3E, $40, $3E, $A2, $81, $08
    dc.b $0B, $3E, $A1, $3C, $3E, $40, $3E, $A2
    dc.b $81, $08, $0B, $3E, $A1, $3C, $3E, $40
fmtune_seq49: ; 0x10E70 - 0x10E9F
    dc.b $3E, $A2, $81, $08, $0B, $3E, $A1, $3C
    dc.b $3E, $40, $3E, $A2, $81, $08, $0B, $3E
    dc.b $A1, $3C, $3E, $40, $3E, $40, $3E, $42
    dc.b $43, $A2, $81, $06, $13, $43, $81, $06
    dc.b $13, $43, $A4, $81, $0A, $05, $42, $81
    dc.b $0A, $0A, $40, $81, $0A, $08, $3E, $A2
fmtune_seq50: ; 0x10EA0 - 0x10ECF
    dc.b $81, $06, $07, $3E, $81, $06, $07, $3E
    dc.b $A4, $3E, $A2, $81, $06, $06, $3C, $3C
    dc.b $3B, $39, $A1, $3C, $3E, $40, $3E, $A2
    dc.b $81, $08, $0B, $3E, $A1, $3C, $3E, $40
    dc.b $3E, $A2, $81, $08, $0B, $3E, $A1, $3C
    dc.b $3E, $40, $3E, $A2, $81, $08, $0B, $3E
fmtune_seq51: ; 0x10ED0 - 0x10EFF
    dc.b $A1, $3C, $3E, $40, $3E, $A2, $81, $08
    dc.b $0B, $3E, $A1, $3C, $3E, $40, $3E, $40
    dc.b $3E, $42, $43, $A2, $81, $0A, $0D, $40
    dc.b $A4, $45, $A2, $81, $0A, $0D, $40, $A4
    dc.b $45, $A2, $81, $0A, $0D, $40, $A4, $45
    dc.b $A2, $81, $0A, $0D, $40, $A4, $45, $A4
fmtune_seq52: ; 0x10F00 - 0x10F2F
    dc.b $81, $0A, $08, $45, $81, $0A, $08, $45
    dc.b $84, $80, $01, $A2, $21, $21, $21, $21
    dc.b $21, $1C, $1F, $21, $1A, $1A, $1A, $1A
    dc.b $1A, $1A, $1A, $1A, $A2, $21, $21, $21
    dc.b $21, $21, $1C, $1F, $21, $26, $26, $26
    dc.b $26, $26, $1E, $1F, $20, $A2, $21, $21
fmtune_seq53: ; 0x10F30 - 0x10F5F
    dc.b $2D, $2D, $2D, $1C, $2F, $2D, $1A, $26
    dc.b $1D, $1E, $26, $26, $25, $23, $1C, $1C
    dc.b $1C, $1C, $20, $21, $22, $23, $28, $28
    dc.b $28, $28, $28, $28, $1F, $20, $84, $80
    dc.b $01, $A6, $1F, $A2, $1F, $A4, $1F, $A2
    dc.b $26, $24, $A6, $1D, $A2, $1D, $A4, $1D
fmtune_seq54: ; 0x10F60 - 0x10F8F
    dc.b $A4, $1F, $A6, $24, $A2, $24, $A4, $24
    dc.b $A2, $26, $28, $A6, $26, $A2, $26, $A4
    dc.b $26, $A4, $26, $A6, $1F, $A2, $1F, $A4
    dc.b $1F, $A2, $26, $24, $A6, $1D, $A2, $1D
    dc.b $A4, $1D, $A4, $1F, $A6, $24, $A2, $24
    dc.b $A4, $24, $A2, $26, $24, $A6, $1D, $1F
fmtune_seq55: ; 0x10F90 - 0x10FBF
    dc.b $A4, $1F, $84, $A6, $21, $A2, $21, $A4
    dc.b $21, $A2, $2A, $28, $A6, $26, $A2, $26
    dc.b $A4, $26, $A4, $1C, $A6, $21, $A2, $21
    dc.b $A4, $21, $A2, $2A, $28, $A6, $26, $A2
    dc.b $26, $A4, $26, $A4, $1C, $A6, $21, $A2
    dc.b $21, $A4, $21, $A2, $2A, $28, $A6, $26
fmtune_seq56: ; 0x10FC0 - 0x10FEF
    dc.b $A2, $26, $A4, $26, $A4, $23, $A6, $1C
    dc.b $A2, $1C, $A4, $1C, $A2, $26, $1C, $A6
    dc.b $1C, $1C, $A4, $1F, $84, $80, $03, $A2
    dc.b $09, $A4, $09, $A2, $09, $80, $04, $A4
    dc.b $15, $80, $03, $09, $84, $80, $12, $86
    dc.b $00, $80, $AA, $37, $A2, $32, $37, $81
fmtune_seq57: ; 0x10FF0 - 0x1101F
    dc.b $0A, $0B, $37, $A6, $81, $0A, $0B, $37
    dc.b $A6, $37, $A4, $81, $0A, $0A, $35, $B0
    dc.b $81, $14, $05, $35, $A6, $81, $0E, $06
    dc.b $32, $81, $0E, $05, $30, $A4, $30, $AA
    dc.b $32, $A2, $32, $37, $81, $0A, $0B, $37
    dc.b $A6, $81, $0A, $0B, $37, $A6, $37, $A4
fmtune_seq58: ; 0x11020 - 0x1104F
    dc.b $81, $0C, $06, $3B, $B0, $81, $10, $0C
    dc.b $39, $A6, $81, $0A, $0B, $37, $37, $A4
    dc.b $35, $84, $80, $06, $86, $00, $80, $AC
    dc.b $81, $0E, $09, $39, $A4, $60, $AC, $81
    dc.b $0E, $0A, $3A, $A4, $60, $AC, $81, $0E
    dc.b $0E, $39, $A4, $60, $A6, $81, $0A, $0A
fmtune_seq59: ; 0x11050 - 0x1107F
    dc.b $3A, $3B, $A4, $39, $AC, $81, $0E, $07
    dc.b $41, $A4, $60, $A6, $81, $0A, $04, $40
    dc.b $A6, $40, $A4, $81, $0C, $08, $41, $B0
    dc.b $81, $10, $08, $35, $A6, $81, $0A, $04
    dc.b $40, $40, $A4, $3E, $84, $80, $11, $A4
    dc.b $2B, $A2, $60, $AA, $2B, $A2, $60, $A2
fmtune_seq60: ; 0x11080 - 0x110AF
    dc.b $2B, $60, $2B, $A4, $29, $2B, $A4, $2B
    dc.b $A2, $60, $AA, $2B, $A2, $60, $A2, $2B
    dc.b $60, $2B, $A4, $29, $2B, $A4, $2B, $A2
    dc.b $60, $AA, $2B, $A2, $60, $A2, $2B, $60
    dc.b $2B, $A4, $29, $2B, $A4, $2B, $A2, $60
    dc.b $A4, $2B, $A2, $60, $A4, $2B, $A4, $29
fmtune_seq61: ; 0x110B0 - 0x110DF
    dc.b $A2, $60, $A4, $2B, $A2, $60, $A4, $2B
    dc.b $84, $80, $11, $A4, $26, $A2, $60, $AA
    dc.b $26, $A2, $60, $A2, $26, $60, $26, $A4
    dc.b $24, $26, $A4, $26, $A2, $60, $AA, $26
    dc.b $A2, $60, $A2, $26, $60, $26, $A4, $24
    dc.b $26, $A4, $26, $A2, $60, $AA, $26, $A2
fmtune_seq62: ; 0x110E0 - 0x1110F
    dc.b $60, $A2, $26, $60, $26, $A4, $24, $26
    dc.b $A4, $24, $A2, $60, $A4, $26, $A2, $60
    dc.b $A4, $24, $A4, $24, $A2, $60, $A4, $26
    dc.b $A2, $60, $A4, $26, $84, $80, $03, $A2
    dc.b $09, $09, $80, $04, $15, $80, $03, $A2
    dc.b $09, $80, $03, $A2, $09, $09, $80, $04
fmtune_seq63: ; 0x11110 - 0x1113F
    dc.b $15, $80, $03, $A2, $09, $84, $80, $03
    dc.b $A2, $09, $09, $80, $04, $15, $80, $03
    dc.b $A2, $09, $80, $03, $09, $80, $04, $15
    dc.b $15, $80, $03, $09, $84, $80, $03, $A2
    dc.b $09, $80, $04, $15, $80, $03, $09, $09
    dc.b $80, $04, $15, $80, $03, $09, $09, $80
fmtune_seq64: ; 0x11140 - 0x1116F
    dc.b $04, $15, $80, $03, $09, $80, $04, $15
    dc.b $15, $80, $03, $09, $80, $04, $15, $15
    dc.b $15, $A1, $15, $15, $84, $A2, $80, $04
    dc.b $15, $80, $03, $09, $09, $80, $04, $15
    dc.b $80, $03, $09, $80, $03, $09, $80, $04
    dc.b $15, $A1, $15, $15, $84, $80, $11, $A2
fmtune_seq65: ; 0x11170 - 0x1119F
    dc.b $60, $A2, $2D, $2D, $60, $2D, $2D, $60
    dc.b $2D, $60, $2D, $A3, $2D, $A1, $60, $A3
    dc.b $2D, $A1, $60, $A4, $2D, $A2, $60, $A2
    dc.b $2D, $2D, $60, $2D, $2D, $60, $2D, $60
    dc.b $2D, $A3, $2D, $A1, $60, $A3, $2D, $A1
    dc.b $60, $A4, $2D, $A2, $60, $A2, $2D, $2D

; Continuation of sequence data in 68k assembly format
fmtune_seq66: ; 0x111A0 - 0x111CF
    dc.b $60, $2D, $2D, $60, $2D, $60, $2D, $A3, $2D, $A1, $60, $A3, $2D, $A1, $60, $A4, $2D, $A2, $60, $A2, $28, $28, $60, $26, $28, $60, $28, $60, $28, $A3, $28, $A1, $60, $A3, $28, $A1, $60, $A4, $28, $84, $80, $11, $A2, $60, $A2, $28, $28, $60 

fmtune_seq67: ; 0x111D0 - 0x111FF
    dc.b $26, $28, $60, $26, $60, $24, $A3, $26, $A1, $60, $A3, $28, $A1, $60, $A4, $26, $A2, $60, $A2, $28, $28, $60, $26, $28, $60, $26, $60, $24, $A3, $26, $A1, $60, $A3, $28, $A1, $60, $A4, $26, $A2, $60, $A2, $28, $28, $60, $26, $28, $60, $26 

fmtune_seq68: ; 0x11200 - 0x1122F
    dc.b $60, $24, $A3, $26, $A1, $60, $A3, $28, $A1, $60, $A4, $26, $A2, $60, $A2, $23, $23, $60, $21, $23, $60, $23, $60, $23, $A3, $23, $A1, $60, $A3, $21, $A1, $60, $A4, $23, $84, $80, $01, $A6, $21, $A2, $1E, $A2, $1F, $60, $60, $21, $60, $21

fmtune_seq69: ; 0x11230-0x1125f
    dc.b $A4, $1E, $1F, $1C, $84, $80, $03, $A4
    dc.b $09, $A2, $80, $04, $15, $80, $03, $09
    dc.b $A4, $09, $80, $04, $A2, $15, $80, $03
    dc.b $A2, $09, $84, $80, $03, $A2, $09, $09
    dc.b $A4, $80, $04, $15, $80, $03, $A2, $09
    dc.b $80, $04, $A4, $15, $A1, $15, $15, $84

fmtune_seq70: ; 0x11260-0x1128f
    dc.b $80, $03, $A2, $09, $09, $A2, $80, $04
    dc.b $15, $15, $15, $15, $15, $A1, $15, $15
    dc.b $84, $80, $03, $A4, $09, $A2, $80, $04
    dc.b $15, $80, $03, $A1, $09, $09, $A2, $80
    dc.b $04, $15, $80, $03, $09, $80, $04, $15
    dc.b $A1, $15, $15, $84, $80, $03, $A2, $09

fmtune_seq71: ; 0x11290-0x112bf
    dc.b $A4, $09, $A2, $09, $A4, $09, $80, $04
    dc.b $15, $84, $80, $03, $A6, $09, $A1, $09
    dc.b $09, $A2, $80, $04, $15, $80, $03, $09
    dc.b $80, $04, $15, $80, $03, $09, $84, $80
    dc.b $05, $A6, $2D, $A2, $2A, $A4, $2B, $A2
    dc.b $60, $2D, $60, $2D, $2B, $60, $A4, $32

fmtune_seq72: ; 0x112c0-0x112ef
    dc.b $31, $84, $80, $05, $A6, $28, $A2, $26
    dc.b $A4, $26, $A2, $60, $28, $60, $28, $26
    dc.b $60, $A4, $2D, $2D, $84, $80, $06, $86
    dc.b $00, $80, $A2, $60, $A4, $81, $0C, $09
    dc.b $37, $A2, $37, $A2, $81, $09, $0D, $37
    dc.b $34, $37, $AE, $81, $16, $05, $37, $A2

fmtune_seq73: ; 0x112f0-0x1131f
    dc.b $31, $32, $A2, $34, $60, $60, $36, $37
    dc.b $60, $60, $34, $60, $34, $A4, $32, $A2
    dc.b $81, $0C, $03, $30, $30, $A4, $2B, $A2
    dc.b $60, $A4, $81, $0C, $09, $37, $A2, $37
    dc.b $A2, $81, $09, $0D, $37, $34, $37, $AE
    dc.b $81, $16, $05, $37, $A2, $36, $37, $A2

fmtune_seq74: ; 0x11320-0x1134f
    dc.b $39, $60, $60, $3E, $3D, $60, $60, $81
    dc.b $0A, $08, $3E, $60, $81, $0A, $08, $3E
    dc.b $A4, $3E, $A2, $3E, $81, $0C, $03, $3C
    dc.b $3C, $39, $84, $80, $06, $86, $00, $80
    dc.b $A2, $60, $A4, $81, $0C, $07, $32, $A2
    dc.b $32, $A2, $81, $09, $09, $32, $31, $32

fmtune_seq75: ; 0x11350-0x1137f
    dc.b $AE, $81, $16, $04, $32, $A2, $34, $36
    dc.b $A2, $37, $60, $60, $39, $3B, $60, $60
    dc.b $37, $60, $37, $A4, $36, $A2, $60, $60
    dc.b $A4, $60, $A2, $60, $A4, $81, $0C, $07
    dc.b $32, $A2, $32, $A2, $81, $09, $09, $32
    dc.b $31, $32, $AE, $81, $16, $04, $32, $A2

fmtune_seq76: ; 0x11380-0x113af
    dc.b $39, $3B, $A2, $3D, $60, $60, $42, $40
    dc.b $60, $60, $81, $0A, $05, $42, $60, $81
    dc.b $0A, $05, $42, $A4, $42, $A2, $42, $81
    dc.b $0C, $03, $3F, $3F, $3D, $84, $80, $01
    dc.b $B0, $21, $B0, $1F, $AE, $28, $AE, $28
    dc.b $A4, $1F, $84, $80, $05, $B0, $21, $B0

fmtune_seq77: ; 0x113b0-0x113df
    dc.b $1F, $AE, $1C, $AE, $1C, $A4, $1F, $84
    dc.b $80, $01, $A2, $21, $A4, $2D, $A2, $2D
    dc.b $2D, $28, $2B, $2D, $AC, $2B, $A2, $24
    dc.b $26, $A2, $28, $A4, $28, $A2, $28, $A4
    dc.b $28, $A2, $60, $28, $60, $28, $A4, $26
    dc.b $A2, $81, $0C, $03, $24, $24, $A4, $1F

fmtune_seq78: ; 0x113e0-0x1140f
    dc.b $84, $80, $05, $A2, $21, $A4, $2D, $A2
    dc.b $2D, $2D, $28, $2B, $2D, $AC, $2B, $A2
    dc.b $24, $26, $A2, $28, $A4, $28, $A2, $28
    dc.b $A4, $28, $A2, $60, $28, $60, $28, $A4
    dc.b $26, $A2, $81, $0C, $03, $24, $24, $A4
    dc.b $1F, $84, $80, $06, $86, $00, $80, $A2

fmtune_seq79: ; 0x11410-0x1143f
    dc.b $21, $A4, $81, $0C, $09, $2B, $A2, $2D
    dc.b $81, $0C, $09, $2B, $28, $2B, $81, $0C
    dc.b $09, $2B, $AC, $2B, $A2, $24, $26, $A2
    dc.b $28, $A4, $81, $0C, $07, $26, $A2, $28
    dc.b $A4, $81, $0C, $07, $26, $A2, $60, $81
    dc.b $0C, $07, $26, $60, $81, $0C, $07, $26

fmtune_seq80: ; 0x11440-0x1146f
    dc.b $A4, $26, $A2, $81, $0C, $03, $24, $24
    dc.b $A4, $1F, $84, $80, $01, $A6, $1F, $A2
    dc.b $23, $A2, $24, $60, $60, $1F, $60, $A4
    dc.b $1F, $21, $A2, $1A, $A4, $24, $A6, $1F
    dc.b $A2, $23, $A2, $24, $60, $60, $1F, $60
    dc.b $1F, $1F, $A4, $60, $A6, $24, $A6, $1F

fmtune_seq81: ; 0x11470-0x1149f
    dc.b $A2, $23, $A2, $24, $60, $60, $1F, $60
    dc.b $A4, $1F, $21, $A2, $1A, $A4, $24, $A6
    dc.b $1F, $A2, $23, $A2, $24, $60, $60, $1F
    dc.b $60, $1F, $1F, $24, $24, $24, $24, $24
    dc.b $84, $80, $05, $A6, $32, $A2, $2F, $A4
    dc.b $30, $A2, $60, $32, $60, $A4, $32, $30

fmtune_seq82: ; 0x114a0-0x114cf
    dc.b $A2, $32, $A4, $34, $A6, $32, $A2, $2F
    dc.b $A4, $30, $A2, $60, $32, $60, $32, $2F
    dc.b $A4, $60, $A6, $32, $A6, $32, $A2, $2F
    dc.b $A4, $30, $A2, $60, $32, $60, $A4, $32
    dc.b $30, $A2, $32, $A4, $34, $A6, $32, $A2
    dc.b $2F, $A4, $30, $A2, $60, $32, $60, $32

fmtune_seq83: ; 0x114d0-0x114ff
    dc.b $2F, $AA, $34, $84, $80, $05, $A6, $2B
    dc.b $A2, $2B, $A4, $2B, $A2, $60, $2B, $60
    dc.b $A4, $2B, $2D, $A2, $2B, $A4, $2B, $A6
    dc.b $2B, $A2, $2B, $A4, $2B, $A2, $60, $2B
    dc.b $60, $2B, $2B, $A4, $60, $A6, $2B, $A6
    dc.b $2B, $A2, $2B, $A4, $2B, $A2, $60, $2B

fmtune_seq84: ; 0x11500-0x1152f
    dc.b $60, $A4, $2B, $2D, $A2, $2B, $A4, $2B
    dc.b $A6, $2B, $A2, $2B, $A4, $2B, $A2, $60
    dc.b $2B, $60, $2B, $2B, $AA, $2B, $84, $80
    dc.b $06, $86, $00, $80, $A2, $60, $37, $3E
    dc.b $81, $0A, $08, $3E, $A8, $81, $10, $05
    dc.b $3E, $A2, $60, $81, $0A, $04, $40, $40

fmtune_seq85: ; 0x11530-0x1155f
    dc.b $43, $60, $81, $0A, $04, $40, $A4, $81
    dc.b $0D, $06, $3E, $A2, $60, $37, $3E, $81
    dc.b $0A, $08, $3E, $A8, $81, $10, $05, $3E
    dc.b $A2, $60, $41, $81, $0A, $0A, $41, $A4
    dc.b $60, $A8, $81, $14, $0A, $45, $A2, $37
    dc.b $3E, $81, $0A, $08, $3E, $A8, $81, $10

fmtune_seq86: ; 0x11560-0x1158f
    dc.b $05, $3E, $A2, $60, $81, $0A, $04, $40
    dc.b $40, $43, $60, $81, $0A, $04, $40, $A4
    dc.b $81, $0D, $06, $3E, $A2, $60, $37, $3E
    dc.b $81, $0A, $08, $3E, $A8, $81, $10, $05
    dc.b $3E, $A2, $60, $81, $0A, $04, $40, $40
    dc.b $81, $0A, $0A, $41, $81, $0A, $0A, $41

fmtune_seq87: ; 0x11590-0x115bf
    dc.b $81, $0A, $0A, $41, $81, $0A, $0A, $41
    dc.b $81, $0A, $0A, $41, $84, $80, $06, $86
    dc.b $00, $80, $A2, $60, $37, $3B, $81, $0A
    dc.b $07, $3B, $A8, $81, $10, $08, $3A, $A2
    dc.b $60, $81, $0A, $07, $3C, $3C, $3E, $60
    dc.b $81, $0A, $07, $3C, $A4, $81, $0D, $05

fmtune_seq88: ; 0x115c0-0x115ef
    dc.b $3B, $A2, $60, $37, $3B, $81, $0A, $07
    dc.b $3B, $A8, $81, $10, $08, $3A, $A2, $60
    dc.b $3E, $81, $0A, $07, $3C, $A4, $60, $A8
    dc.b $81, $12, $04, $3E, $A2, $37, $3B, $81
    dc.b $0A, $07, $3B, $A8, $81, $10, $08, $3A
    dc.b $A2, $60, $81, $0A, $07, $3C, $3C, $3E

fmtune_seq89: ; 0x115f0-0x11623
    dc.b $60, $81, $0A, $07, $3C, $A4, $81, $0D
    dc.b $05, $3B, $A2, $60, $37, $3B, $81, $0A
    dc.b $07, $3B, $A8, $81, $10, $08, $3A, $A2
    dc.b $60, $81, $0A, $07, $3C, $3C, $81, $0A
    dc.b $07, $3C, $81, $0A, $07, $3C, $81, $0A
    dc.b $07, $3C, $81, $0A, $07, $3C, $81, $0A
    dc.b $07, $3C, $84, $00

; Resets the Z80 processor with a synchronization delay.
Sound_ResetZ80:
    movem.l d0/a0,-(sp)             ; Save registers d0 and a0
    move.w  #$100,(IO_Z80BUS).l     ; Request Z80 bus to stop Z80
    move.w  #0,(IO_Z80RES).l        ; Assert Z80 reset line
    move.w  #0,(IO_Z80BUS).l        ; Release Z80 bus
    move.w  #$1F4,d0                ; Set delay counter to 500
.z80_sync_wait
    dbf     d0,.z80_sync_wait       ; Loop to delay for synchronization
    move.w  #$100,(IO_Z80RES).l     ; Deassert Z80 reset to start Z80
    movem.l (sp)+,d0/a0             ; Restore registers d0 and a0
    rts                             ; Return

; Loads the Z80 sound program into Z80 RAM and resets Z80.
Sound_LoadZ80Program:
    movem.l d0-d2/a0-a2,-(sp)       ; Save registers d0-d2, a0-a2
    move.w  #$100,(IO_Z80RES).l     ; Deassert Z80 reset
    move.w  #$100,(IO_Z80BUS).l     ; Request Z80 bus
    lea     Z80_Program_Code(pc),a1 ; Load source address of Z80 program
    movea.l #Z80_RAM,a2             ; Load destination Z80 RAM base
    move.w  #$597,d0                ; Set counter for $598 bytes -1
    bra.s   .load_z80_byte_loop2    ; Branch to loop
.load_z80_byte_loop
    move.b  (a1)+,(a2)+             ; Copy byte from source to destination
.load_z80_byte_loop2
    dbf     d0,.load_z80_byte_loop  ; Loop until all bytes copied
    move.w  #0,(IO_Z80RES).l        ; Assert Z80 reset
    move.w  #0,(IO_Z80BUS).l        ; Release Z80 bus
    move.w  #$1F4,d0                ; Set delay counter to 500
.z80_sync_delay_loop
    dbf     d0,.z80_sync_delay_loop ; Loop to delay for synchronization
    move.w  #$100,(IO_Z80RES).l     ; Deassert Z80 reset
    movem.l (sp)+,d0-d2/a0-a2       ; Restore registers
    rts                             ; Return

Z80_Program_Code
    incbin ..\Extracted\Sound\z80_snd_drv.bin
; { name: 'sfx_puckwall1_pcm.bin', folder: 'Sound', start: 0x11C3E, end: 0x12A58 },
sfx_puckwall1_pcm
    incbin ..\Extracted\Sound\sfx_puckwall1_pcm.bin
; { name: 'sfx_puckbody_pcm.bin', folder: 'Sound', start: 0x12A58, end: 0x13960 }, // also partially used for fm_instrument_patch_sfx_id_3
sfx_puckbody_pcm
    incbin ..\Extracted\Sound\sfx_puckbody_pcm.bin
; { name: 'sfx_puckget_pcm.bin', folder: 'Sound', start: 0x13960, end: 0x14886 },
sfx_puckget_pcm
    incbin ..\Extracted\Sound\sfx_puckget_pcm.bin
; { name: 'sfx_puckpost-1_pcm.bin', folder: 'Sound', start: 0x14886, end: 0x15768 }, // puckwall3-1, puckice-1
sfx_puckpost_pcm
    incbin ..\Extracted\Sound\sfx_puckpost-1_pcm.bin
; { name: 'sfx_check_pcm.bin', folder: 'Sound', start: 0x15768, end: 0x168AA }, // check2, playerwall
sfx_check_pcm
    incbin ..\Extracted\Sound\sfx_check_pcm.bin
; { name: 'sfx_highhigh_pcm.bin', folder: 'Sound', start: 0x168AA, end: 0x16E04 }, // offset in code is 168B0; hitlow, sfx_id_23
sfx_highhigh_pcm
    incbin ..\Extracted\Sound\sfx_highhigh_pcm.bin
; { name: 'sfx_crowdboo_pcm.bin', folder: 'Sound', start: 0x16E04, end: 0x1D786 },
sfx_crowdboo_pcm
    incbin ..\Extracted\Sound\sfx_crowdboo_pcm.bin
; { name: 'sfx_oooh_pcm.bin', folder: 'Sound', start: 0x1D786, end: 0x1FCE8 },
sfx_oooh_pcm
    incbin ..\Extracted\Sound\sfx_oooh_pcm.bin
; { name: 'sfx_id_31_pcm.bin', folder: 'Sound', start: 0x1FCE8, end: 0x222AA }, // offset in code is 1FD88
sfx_id_31_pcm
    incbin ..\Extracted\Sound\sfx_id_31_pcm.bin
; // is there a break at 0x1FFA3?
; { name: 'sfx_check3_pcm.bin', folder: 'Sound', start: 0x222AA, end: 0x00024214 }, // sfx_id_4
sfx_check3_pcm
    incbin ..\Extracted\Sound\sfx_check3_pcm.bin