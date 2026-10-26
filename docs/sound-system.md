# Sound System

The 68000 and Z80 sound drivers, the SFX and music data formats, and the Z80 driver. The sound effect numbers and names are in [the EA sound list](original/sound-effect-list.md).

## Overview
NHL 92 uses a hybrid sound system: The 68000 CPU handles high-level music/SFX logic (preparing channel data, parsing tracks, envelopes, modulation), while the Z80 co-processor drives the YM2612 FM synthesizer and PSG for low-level output. PCM samples are used for realistic SFX (e.g., puck hits), streamed via DAC.

- **68000 Side (sound.asm)**: Manages 6 channels (FM/PSG). Parses track commands ($80-$8B for instruments, modulation, loops, etc.), computes frequencies/notes (using `note_frequency_table` and `note_octave_table`), applies envelopes/vibrato (`envelope_table`), and prepares Z80 buffers. Entry points like `p_music_vblank_fn` handle VBlank updates. SFX are triggered via `p_initfx_fn` and a pointer table (`sfx_pointer_table`), with handlers initializing channels and command streams.
  
- **Z80 Side ([`src/sound/z80_snd_drv.asm`](../src/sound/z80_snd_drv.asm))**: Loaded into Z80 RAM at $A00000. Its main loop plays one DAC (PCM) byte per pass and, when the 68000 has posted an update, writes the six FM channel slots (patch, key on/off, frequency, carrier level) to the YM2612. It never writes the PSG. See [Z80 Snd Drv](#z80-snd-drv).

- **Interaction**: 68000 writes to shared RAM (e.g., `z80_channel_data_buffer_RAM`), sets flags (`z80_audio_update_flag`), and requests Z80 bus (`IO_Z80BUS`). Z80 reads these and outputs to YM2612/PSG ports ($4000-$4003).

- **Music Tracks**: 5 tracks (e.g., Title, EOP). Pointers in `fmtune_pointer_table` (num channels, tempo, channel data offsets). Sequences (`fmtune_seq0` etc.) use commands like $84 (loop), $88 (pitch adjust).

- **SFX**: 35 entries in `sfx_pointer_table`. Handlers (e.g., `handle_sfx_sam_puck2_slap`) init channels and point to command streams (.bin files). Commands: $80 (instrument), $81 (delay), $83 (frequency sweep), $84 (stop), $85 (loop). Some SFX share streams/PCM (e.g., the player hits boards SFX 15-17 also start `handle_sfx_hitboard`).

- **PCM Samples**: Extracted .bin files (e.g., `sfx_sam_puck2_slap_pcm.bin` at $11C3E). Streamed via DAC (YM2612 reg $2A). Signed 8-bit, ~8kHz. Used for hits, checks, crowd. 

- **FM Instruments**: 22 patches inside the Z80 driver at Z80 $02A5 (ROM $1194B), `z80_fm_patches` in the Z80 source. 32 bytes each: Operator params (multiplier, detune, total level, rate scaling, attack/decay/sustain/release), algorithm/feedback ($B0), stereo ($B4). Examples: Bass ($20,$62,...), Whistle ($43,0,...).

- **Envelopes**: 4 in `envelope_table` (vibrato/pitch bend patterns, e.g., subtle wobble or downward ramp). Signed bytes; $84 loops.

- **Note Tables**: `note_frequency_table` (96 entries, YM2612 freq bytes), `note_octave_table` (96 entries, octave shifts).

- **Build Notes**: `build:sound` assembles the Z80 driver (asm80) and `sound.asm`, which includes it. Use `tools/extractAssets92.js` for .bin files (PCM/cmdstreams). For custom SFX, edit handlers/streams and repoint in table.

## SFX
### SFX pointer table
Pointer table at $1035C (35 entries, longwords relative to `p_music_vblank`). Maps SFX IDs (0-34) to handlers (e.g., $0 = `handle_sfx_siren`). IDs 0-31 are the SFX in EA's list (the `SFX...` equates in `src/ram.asm`); IDs 32-34 are unused duplicates of ID 30 (`handle_sfx_hitboard2vols`). ID 31 (`handle_sfx_oooh`) has its own handler.

### SFX handler
Handlers (e.g., `handle_sfx_sam_puck2_slap`) load YM2612 params or init channels via `Sound_InitSFXChannel`. Many write direct to YM2612 (e.g., `Sound_WriteYM2612`) for freq/volume, or chain to others (e.g., `handle_sfx_sam_hitboard1` chains to `handle_sfx_hitboard`).

### SFX cmdstream
Extracted .bin files (e.g., `sfx_siren_cmdstream_ch0.bin` at $FF74). Byte streams parsed in `Sound_Process_SFXChannels`: $80 (set instrument), $81/$82 (delay/alt delay), $83 (freq sweep: counter, base freq, increment), $84 (stop), $85 (loop). Frequency normalized to YM2612 range ($000-$7FF).

### SFX PCM
Extracted signed 8-bit PCM .bin files (e.g., `sfx_sam_puck2_slap_pcm.bin` 0x11C3E-0x12A58). Streamed via DAC. Some are shared by several SFX (e.g., `sfx_sam_hit_pcm` for checks 18-20). Sample rates ~8-11kHz based on counters.

### Instrument patches
Loaded via $80 command. Params: 4 operators (mul/dt/tl/rs/ar/dr/sr/rr/ssg-eg), alg/fb, stereo. 25+ defined. Some handlers pass a PCM sample offset as a constant (`sfx_skating34_pcm_ofs` = $12DE2, `sfx_oooh_pcm_ofs` = $10820; formerly named `fm_instrument_patch_sfx_id_3` / `_31`).

## Note Frequency Table
At $1017A (96 bytes): YM2612 freq low bytes for notes (C0-B7, incl. sharps). E.g., C0=$02, C#0=$03. Used in `process_note_frequency` with octave shifts.

## Note Octave Table
At $101DA (96 bytes): Freq high/octave bits. E.g., C0=$84, C1=$AA. Combined with freq table for full 11-bit YM2612 freq.

## Envelope Table
At $1023A (4 long ptrs to envelopes). Signed vibrato/detune patterns ($00 neutral, positive up, negative down; $84 loop). E.g., Envelope0: subtle oscillate (0,+1,+1,0,-1,-2,-1,0,loop). Applied in `check_envelope` for pitch/volume modulation.

## FMTunes
### fmtune pointer table
At $10294 (5 entries, 26 bytes each): Num FM/PSG channels (word), 6 long ptrs to channel data (rel to `p_music_vblank`). E.g., Title ($0506, ch0-5 ptrs).

### fmtune channel table
Channel offsets (e.g., `fmtune_eop_ch0` at $10568): Words pointing to sequences (e.g., $11A3 = seq0). Up to 6 channels per track.

### fmtune sequence table
Sequences (`fmtune_seq0` at $1061E+): Byte streams for notes/rests ($00-$5F note/rest, $60 rest), commands ($80+ as in SFX but music-specific: $80 instr, $81 mod, $83 sustain, $84 loop, $85 stop, $86 env, $87 clear env, $88 pitch, $89 flag, $8A skip, $8B SFX). Durations $8C-$9F (multiplied by tempo).

## Z80 Snd Drv
Source: [`src/sound/z80_snd_drv.asm`](../src/sound/z80_snd_drv.asm), assembled with asm80 by the build's `z80` step into `output/<mode>/obj/z80_snd_drv.bin` and included by `sound.asm` at `Z80_Program_Code` (ROM $116A6-$11C3D, $598 bytes). The build checks the assembled driver byte-for-byte against the ROM. `Sound_LoadZ80Program` copies $597 of those bytes (the comment there says $598); the last byte ($6E) never reaches Z80 RAM. The older IDA-style listing [`z80_snd_drv.lst`](z80_snd_drv.lst) is kept for reference only: it does not match the bytes in several places (for example it shows `im 1`, the driver uses `im 0`; and its routine addresses and names don't line up with the code), so use the source.

Z80 RAM layout (names as in the source; the 68000 names from `sound.asm` are used for the shared bytes):

| Z80 address | Name | What it is |
|---|---|---|
| $0000 | `Z80_DriverStart` | `jp Z80_Init`; $0003-$0037 unused (zero) |
| $0038 | `Z80_Init`, `MainLoop` | Stack $1FFF, interrupts off; main loop: DAC byte, FM update, rate delay |
| $007A | `z80_dac_rate` | Operand of the DAC delay loop (self-modified), from `z80_sfxparam3` |
| $00A8, $00B0, $00B2 | `z80_dac_start_bank`, `z80_dac_start_addr_high/low` | Operands of `DacStartSample` (self-modified) |
| $00BE-$00C3 | `z80_sfxparam1`, `z80_sfx_control_ram`, `z80_sfxparam2`-`5` | DAC sample mailbox: address low, address high \| $80, request (0 = new), rate, bank, priority |
| $00C4 | `z80_dac_priority` | Priority of the playing sample ($FF = none); a request needs an equal or lower value |
| $00C5 | `FmPatchRegisters` | The 26 YM2612 registers of a patch, in patch byte order, 0-terminated |
| $00E0 | `UpdateFmChannels` / `CheckSfxRequest` | Writes the 6 slots, then takes a pending DAC request |
| $0242, $0250 | `WriteYmPart1`, `WriteYmPart2` | A = register, C = data, push/pop delay between |
| $025E | `UnusedDacWriteIY` | Never called |
| $0273-$02A2 | `z80_channel_data_buffer` | 6 x 8-byte slots (`z80slot_*`), FM key codes 0, 1, 2, 4, 5, 6 |
| $02A3 | `z80_audio_update_flag` | 68000 writes 0 for new slot data; driver sets 1 when done |
| $02A4 | `z80_dac_state` | 0 = start sample, 1 = playing, $FF = idle |
| $02A5 | `z80_fm_patches` | 22 patches x 32 bytes (26 register bytes, note offset at +$1A, 5 unused) |
| $0569 | `SetBank`, `z80_bank_number` ($056A) | 9-bit serial write to the bank register at $6000 |

DAC samples are read through the $8000 bank window, starting one byte after the requested address. A 0 byte ends the sample; if the next byte is 1 the sample restarts. When the window address wraps past $FFFF the driver moves to the next bank.
