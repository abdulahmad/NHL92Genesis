# NHL92Genesis
Bitwise perfect compilable source of NHL Hockey (aka NHL 92) for Sega Genesis. Includes fully disassembled sound driver. Requires original ROM file to build.

Built on the work that McMarkis (https://github.com/Mhopkinsinc/NHLHockey) did to get the source compiling.

## Features of this version:
- Retail version is bitwise perfect with retail ROM. Rev A Dev build is bitwise perfect with Rev A Dev build included with original release.
- Documentation of all File Formats used within the game
- Script which changes opcodes to match the custom compiler EA used to build the game
- Disassembled Retail Validation Check code included via checksum env variable
- Env vars allows build of Retail version (includes validation code), Rev A "retail" version (includes validation code) or Rev A Dev version (no validation code)
- Script to generate CRC16 Checksum used in ROM Header & CRC32 Checksum used in Validation code
- EA Logo code is disassembled and buildable
- Sound Driver code is disassembled and buildable
- Script to extract assets from retail rom (Graphics, PCM audio, FM audio, z80 snd driver)
- Requires retail ROM

## Instructions

1. Install node from https://nodejs.org/en/download if it isn't already installed on your machine

2. In the `NHL92Genesis` folder, run `npm i` to install `node_modules`

3. Copy the NHL Hockey (NHL92) Sega Genesis ROM file into the `NHL92Genesis` folder

4. Run `node .\extractAssets92.js <nhl92RomFileName>` to extract assets from the NHL Hockey (NHL 92) ROM file into the `Extracted` folder

5. Run `npm run build:logo` to build `EALogo.bin` (`modified_EALogo.bin` is the opcode corrected version)

6. Run `npm run build:sound` to build `Hockey.snd` (`modified_Hockey.snd` is the opcode corrected version)

7. You have the choice of building 3 versions:

    - For the `Retail` ROM, run `npm run build:retail` -- this includes the retail checksum validation check (modified_nhl92.bin is the opcode corrected version)

    - For the `Rev A` ROM, run `npm run build:reva` -- this includes the retail checksum validation check (modified_nhl92.bin is the opcode corrected version)

    - For developing your own version, run `npm run build:dev` -- this uses `Rev A` flags and does not include the retail checksum validation check  (modified_nhl92.bin is the opcode corrected version)

# Documentation

## Developing on this build
You need to build using `build:dev` to avoid the checksum validation. By default, this builds the `Rev A` version of the code. If for whatever reason, you do want to enforce checksum validation on your build, you need to use the `generateChecksum.js` script. Also, you need to do 2 passes of the script & updating the checksums to end up with the correct checksum for both CRC16 and CRC32. The game will not start if checksum validation is enabled and the checksum is incorrect.

## Retail (REV=0) vs Rev A (REV=1)
The original source code that was released was in a state that was post-retail code, and had some fixes (which are mentioned down below). I'm not sure if this is an undumped late print run retail version, but it might be. As such, I've resorted to calling this newly discovered version of NHL92 `Rev A`.

### Overall Differences Between Retail (REV=0) vs Rev A (REV=1)
- **Bug Fixes Focus**: `Rev A` adds safeguards against crashes (e.g., extra RAM clearing, SR register settings), sound glitches (e.g., explicit crowd sound kills), and logic errors (e.g., bitmasking in playoff resolution to prevent overflow or invalid states). It also includes minor UI/alignment tweaks (e.g., different padding bytes or string parameters).
- **No Major Features Added**: Changes are subtle; no new gameplay mechanics, graphics, or levels. Rev=1 seems like a post-release patch for stability, especially in playoff modes and demo/initialization sequences.
- **Performance/Stability**: Extra RAM clears and SR (Status Register) manipulations suggest fixes for undefined behavior or memory corruption in `Retail`. Sound-related calls (e.g., `KillCrowd`) likely fix lingering audio issues.
- **Size/Alignment**: Some differences are padding bytes (e.g., `$E7` vs `$FF`), possibly to adjust ROM checksums, alignment, or fix disassembly issues in tools/compilers.
- **Playoff Logic**: `Rev A` adds bitmasking to ensure valid states in playoff trees, preventing progression bugs (e.g., infinite loops or invalid wins).
- **Total Changes**: About 10 distinct conditional blocks, mostly small (1-10 lines each). Rev=1 is "heavier" on initialization and error handling.

### Specific Differences and Comments

1. **Location**: `Begin` routine (startup RAM clearing, after initial clear to `varend2`).
   - **Rev=0 (Retail) Code**:
     ```
     move	#$2700,SR	
     move.l	#Stack,sp	
     move.l	#varstart,a0	;clear out ram
     .1	clr.l	(a0)+
     cmp.l	#varend,a0
     blt	.1
     ```
   - **Rev=1 (Revision A) Code**: Omitted (no additional clear).
   - **Description/Comment**: Rev=0 performs a second RAM clear from `varstart` to `varend` (after an earlier clear to `varend2`). This might be redundant or a workaround for incomplete clearing in Rev=0. Rev=1 removes it, assuming the initial clear (to `varend2`) is sufficient—likely a fix for over-clearing that could cause performance issues or overwrite valid data. `varend` and `varend2` are likely different RAM boundaries (e.g., `varend2` includes extra vars), so Rev=1 optimizes to avoid double work. Potential bug fixed: Memory corruption if `varend` < `varend2`.

2. **Location**: End of `priolist` data table (player position priorities).
   - **Rev=0 (Retail) Code**: `dc.b $E7`
   - **Rev=1 (Revision A) Code**: `dc.b $FF`
   - **Description/Comment**: Padding byte after the priority list (`dc.b 0,1,2,4,3,5,6`). `$E7` (231 decimal) vs `$FF` (255/all bits set). This could be for ROM alignment, checksum adjustment, or to mark the end of data (e.g., `$FF` as a sentinel value). No functional impact on gameplay, but might fix disassembly/tools issues or prevent buffer overflows in data reads. Minor tweak, not a bug fix per se.

3. **Location**: End of `.alist` data table (player assignment list).
   - **Rev=0 (Retail) Code**: `dc.b $7C`
   - **Rev=1 (Revision A) Code**: `dc.b $FF`
   - **Description/Comment**: Similar to above—padding after `dc.b agoalie, adefd, ... , acenterd`. `$7C` (124) vs `$FF`. Likely alignment/checksum. `$FF` is a common "end marker" in assembly data tables. Negligible impact, but could prevent invalid reads if code overruns the table.

4. **Location**: `TitleScreen` routine (title screen setup).
   - **Rev=0 (Retail) Code**: Omitted.
   - **Rev=1 (Revision A) Code**: `bsr KillCrowd`
   - **Description/Comment**: Rev=1 explicitly calls `KillCrowd`. This fixes a bug where crowd sounds from previous games/demos persist into the title screen, causing audio glitches. Improves user experience by ensuring clean audio on startup.

5. **Location**: `Opening2` routine (game restart/entry point).
   - **Rev=0 (Retail) Code**:
     ```
     move.l	#Stack,sp
     ```
   - **Rev=1 (Revision A) Code**:
     ```
     move	#$2700,SR
     move	#Stack,sp
     move	#varstart,a0
     .0		clr.l	(a0)+
     cmp	#varend,a0
     blt	.0
     move.l	#vb2,vbint
     move	#$2500,sr
     ```
   - **Description/Comment**: Rev=1 adds full reinitialization: Sets SR to supervisor mode (`$2700`), resets stack, clears RAM to `varend`, sets VBlank interrupt (`vbint`), and lowers SR to `$2500` (interrupts enabled). Rev=0 only resets the stack, risking leftover data/crashes. Fixes instability on restarts (e.g., after game over), preventing crashes from uninitialized RAM or interrupt issues. Key bug fix for reliability.

6. **Location**: `setoptions` routine (options menu setup).
   - **Rev=0 (Retail) Code**:
     ```
     bset	#dfng,disflags
     move.l	#vb2,vbint
     ```
     (And later: `move.l #vb2,vbint`)
   - **Rev=1 (Revision A) Code**:
     ```
     move	#$2500,sr
     move.l	#vb2,vbint
     bset	#dfng,disflags
     ```
     (Later call omitted.)
   - **Description/Comment**: Rev=1 enables interrupts earlier (`$2500 SR`) and reorders instructions. Rev=0 sets a display flag first and duplicates the VBlank set. Fixes potential timing/interrupt bugs in menu rendering (e.g., flickering or input lag). The omitted duplicate call optimizes code. Stability tweak for menu navigation.

7. **Location**: `.pli` string data (playoff paging messages).
   - **Rev=0 (Retail) Code**: `String $F0` (followed by messages).
   - **Rev=1 (Revision A) Code**: `String $D4` (noted as a macro parameter for matching ROM).
   - **Description/Comment**: Different byte prefixed to strings like `'Regular Season'`. `$F0` vs `$D4` might be a palette/color index or string terminator. Likely fixes text rendering glitches (e.g., color or alignment in playoff screens). Minor UI polish.

8. **Location**: `ResolveGames` routine (playoff resolution, in `.notbos` and `.nextround` sections).
   - **Rev=0 (Retail) Code**: Omitted.
   - **Rev=1 (Revision A) Code**:
     ```
     moveq	#1,d1
     asl	d2,d1
     sub	#1,d1
     and	d1,WinBits
     ```
   - **Description/Comment**: Masks `WinBits` to clear higher bits based on game level (`d2` shift). Prevents bit overflow or invalid win states in playoff trees (e.g., carrying over bits from previous rounds). Fixes progression bugs where games could loop or show wrong winners. Core bug fix for playoff mode reliability.

9. **Location**: `ResolveGames` routine (in `.userfailed` handling).
   - **Rev=0 (Retail) Code**: Direct jump to `.userfailed`.
   - **Rev=1 (Revision A) Code**:
     ```
     cmp	#1,gamelevel
     bne    .userfailed
     ```
   - **Description/Comment**: Skips `.userfailed` if `gamelevel == 1`. Likely fixes a specific playoff failure case (e.g., early rounds in 2-player mode). Prevents premature "failure" states, improving fairness in multi-game series.

10. **Location**: Various data tables (e.g., end of ROM or unused areas).
    - Several instances of `dcb.b` padding with different sizes (e.g., `$124` vs `$108` bytes of `$FF`).
    - **Description/Comment**: ROM filler for alignment or to reach power-of-2 sizes. No functional change, but ensures compatibility with carts/tools. If checksum code is enabled (`IF CHECKSUM=1`), it might relate to security/mastering fixes in Rev=1.

11. **Location**: End of `teamdata.asm`
    - **Rev=0 (Retail) Code**: ```String	'Mark Hughes and Scooter Hanson'```
   - **Rev=1 (Revision A) Code**: ```String	'Mark Hughes and Scooter Henson'```
   - **Description/Comment**: Fixed typo of Scooter Henson's name.

## Sound System Overview
NHL 92 uses a hybrid sound system: The 68000 CPU handles high-level music/SFX logic (preparing channel data, parsing tracks, envelopes, modulation), while the Z80 co-processor drives the YM2612 FM synthesizer and PSG for low-level output. PCM samples are used for realistic SFX (e.g., puck hits), streamed via DAC.

- **68000 Side (sound.asm)**: Manages 6 channels (FM/PSG). Parses track commands ($80-$8B for instruments, modulation, loops, etc.), computes frequencies/notes (using `note_frequency_table` and `note_octave_table`), applies envelopes/vibrato (`envelope_table`), and prepares Z80 buffers. Entry points like `p_music_vblank_fn` handle VBlank updates. SFX are triggered via `p_initfx_fn` and a pointer table (`sfx_pointer_table`), with handlers initializing channels and command streams.
  
- **Z80 Side (z80_snd_drv.bin, disassembled via IDA Pro)**: Loaded into Z80 RAM at $A00000. Main loop (`MainLoop`) waits for flags from 68000, processes FM channels (registers $30-$8C for operators, $B0/$B4 for stereo/algorithm), updates DAC for PCM, and handles PSG. Uses busy-wait loops for timing YM2612 writes. Instruments are patched directly to YM2612 registers.

- **Interaction**: 68000 writes to shared RAM (e.g., `z80_channel_data_buffer_RAM`), sets flags (`z80_audio_update_flag`), and requests Z80 bus (`IO_Z80BUS`). Z80 reads these and outputs to YM2612/PSG ports ($4000-$4003).

- **Music Tracks**: 5 tracks (e.g., Title, EOP). Pointers in `fmtune_pointer_table` (num channels, tempo, channel data offsets). Sequences (`fmtune_seq0` etc.) use commands like $84 (loop), $88 (pitch adjust).

- **SFX**: 35 entries in `sfx_pointer_table`. Handlers (e.g., `handle_sfx_puckwall1`) init channels and point to command streams (.bin files). Commands: $80 (instrument), $81 (delay), $83 (frequency sweep), $84 (stop), $85 (loop). Some SFX share streams/PCM (e.g., puckwall3 uses pass handler).

- **PCM Samples**: Extracted .bin files (e.g., `sfx_puckwall1_pcm.bin` at $12DE2). Streamed via DAC (YM2612 reg $2A). Signed 8-bit, ~8kHz. Used for hits, checks, crowd. Note: Some patches overlap (e.g., `sfx_puckbody_pcm` partially used for FM instruments).

- **FM Instruments**: 25+ patches starting at $11C3E in ROM (loaded to Z80 RAM offset $2A5). 32 bytes each: Operator params (multiplier, detune, total level, rate scaling, attack/decay/sustain/release), algorithm/feedback ($B0), stereo ($B4). Examples: Bass ($20,$62,...), Whistle ($43,0,...).

- **Envelopes**: 4 in `envelope_table` (vibrato/pitch bend patterns, e.g., subtle wobble or downward ramp). Signed bytes; $84 loops.

- **Note Tables**: `note_frequency_table` (96 entries, YM2612 freq bytes), `note_octave_table` (96 entries, octave shifts).

- **Build Notes**: `build:sound` assembles `sound.asm` + Z80 bin + extracts. Use `extractAssets92.js` for .bin files (PCM/cmdstreams). For custom SFX, edit handlers/streams and repoint in table.

## .JIM
Documentation for the NHL92 .JIM file format and tools to import/export to/from .JIM format lives here: https://github.com/abdulahmad/EA-NHL-Tools/tree/main/JIM-Tools

## .ANIM format
Documentation for the NHL92 .ANIM file format and tool to export from .ANIM format lives here: https://github.com/abdulahmad/EA-NHL-Tools/tree/main/ANIM-To-BMP

## .PAL
.pal files use standard Genesis CRAM format for palette. Each color is 2 bytes in Genesis format (0000BBB0GGG0RRR0, where BBB=Blue bits, GGG=Green bits, RRR=Red bits).

## SFX:
### SFX pointer table
Pointer table at $1035C (35 entries, longwords relative to `p_music_vblank`). Maps SFX IDs (0-34) to handlers (e.g., $0 = `handle_sfx_siren`). Some duplicates/share code (e.g., IDs 30-34 all point to `handle_sfx_id_30`).

### SFX handler
Handlers (e.g., `handle_sfx_puckwall1`) load YM2612 params or init channels via `Sound_InitSFXChannel`. Many write direct to YM2612 (e.g., `Sound_WriteYM2612`) for freq/volume, or chain to others (e.g., puckwall3 chains to pass).

### SFX cmdstream
Extracted .bin files (e.g., `sfx_siren_cmdstream_ch0.bin` at $FF74). Byte streams parsed in `Sound_Process_SFXChannels`: $80 (set instrument), $81/$82 (delay/alt delay), $83 (freq sweep: counter, base freq, increment), $84 (stop), $85 (loop). Frequency normalized to YM2612 range ($000-$7FF).

### SFX PCM
Extracted signed 8-bit PCM .bin files (e.g., `sfx_puckwall1_pcm.bin` 0x11C3E-0x12A58). Streamed via DAC. Some shared/partial (e.g., `sfx_puckbody_pcm` overlaps FM patches at $12A58). Sample rates ~8-11kHz based on counters.

### Instrument patches
Loaded via $80 command. Params: 4 operators (mul/dt/tl/rs/ar/dr/sr/rr/ssg-eg), alg/fb, stereo. 25+ defined; some hardcoded in handlers (e.g., `fm_instrument_patch_sfx_id_3` at $12DE2 overlaps PCM).

## Note Frequency Table
At $1017A (96 bytes): YM2612 freq low bytes for notes (C0-B7, incl. sharps). E.g., C0=$02, C#0=$03. Used in `process_note_frequency` with octave shifts.

## Note Octave Table
At $101DA (96 bytes): Freq high/octave bits. E.g., C0=$84, C1=$AA. Combined with freq table for full 11-bit YM2612 freq.

## Envelope Table
At $1023A (4 long ptrs to envelopes). Signed vibrato/detune patterns ($00 neutral, positive up, negative down; $84 loop). E.g., Envelope0: subtle oscillate (0,+1,+1,0,-1,-2,-1,0,loop). Applied in `check_envelope` for pitch/volume modulation.

## FMTunes:
### fmtune pointer table
At $10294 (5 entries, 26 bytes each): Num FM/PSG channels (word), 6 long ptrs to channel data (rel to `p_music_vblank`). E.g., Title ($0506, ch0-5 ptrs).

### fmtune channel table
Channel offsets (e.g., `fmtune_song0_ch0` at $10568): Words pointing to sequences (e.g., $11A3 = seq0). Up to 6 channels per track.

### fmtune sequence table
Sequences (`fmtune_seq0` at $1061E+): Byte streams for notes/rests ($00-$5F note/rest, $60 rest), commands ($80+ as in SFX but music-specific: $80 instr, $81 mod, $83 sustain, $84 loop, $85 stop, $86 env, $87 clear env, $88 pitch, $89 flag, $8A skip, $8B SFX). Durations $8C-$9F (multiplied by tempo).

## Z80 Snd Drv
Binary at $116A6-$11C3D (extracted as z80_snd_drv.bin). Loaded via `Sound_LoadZ80Program`. Disassembled (IDA Pro):

- **Entry**: `Z80_SoundDriver` ($116A6) sets stack ($1FFF), IM1, jumps to `MainLoop` ($116D6).
- **MainLoop**: Checks flags (`FLAG_CONTROL` $02A4). Processes DAC ($2A reg), FM channels (6x, regs $30-$8C via `ProcessFMChannels` $11775), PSG. Busy-waits for YM writes.
- **Channels**: Pointers at $0073. Flags at $00B0. Processes per-channel (key on/off $28, freq $A0/$A4, vol $4C).
- **DAC/PSG**: DAC enable ($2B reg). PSG via shared RAM ($00BE-$00C3).
- **Writes**: `WriteYM2612` ($118DF) / `WriteYM2612Part2` ($118EB) with delays (pop hl for timing).
- **Instruments**: Patched to YM regs (e.g., $30+ for operators).

## Known Issues/Limitations
- **PCM Overlaps**: Some FM patches overlap PCM (e.g., $10820 in fm_instrument_patch_sfx_31). Modding may corrupt audio due to hardcoded address
- **Checksum Sensitivity**: Builds require exact extracts for bitwise match; minor ROM diffs break validation.
- **Z80 Sound Driver**: There is an .lst file in the `sound` folder of the z80 sound driver disassembly, but I haven't gone through the effort of making it part of the build-- the z80 code extracted from the retail rom is used for the build.

## Modding Tips
- **Custom Music**: Edit `fmtune_pointer_table` / sequences. Add notes via freq tables; test envelopes for vibrato.
- **New SFX**: Add to `sfx_pointer_table`, create handler (init channels, YM writes), cmdstream (.bin), PCM if needed.
- **Testing**: Build `dev` for no checksum lock. Monitor shared RAM ($FFFFFE40+) for channel states.
