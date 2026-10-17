# Modding

Building your own version, known limitations and tips.

## Developing on this build
You need to build using `build:dev` to avoid the checksum validation. By default, this builds the `Rev A` version of the code. If for whatever reason, you do want to enforce checksum validation on your build, you need to use the `tools/generateChecksum.js` script (`npm run checksum`). Also, you need to do 2 passes of the script & updating the checksums to end up with the correct checksum for both CRC16 and CRC32. The game will not start if checksum validation is enabled and the checksum is incorrect.

## Known Issues/Limitations
- **PCM Overlaps**: Some FM patches overlap PCM (e.g., `sfx_oooh_pcm_ofs` = $10820). Modding may corrupt audio due to hardcoded address
- **Checksum Sensitivity**: Builds require exact extracts for bitwise match; minor ROM diffs break validation.
- **Z80 Sound Driver**: There is an .lst file of the z80 sound driver disassembly in `docs/z80_snd_drv.lst`, but I haven't gone through the effort of making it part of the build-- the z80 code extracted from the retail rom is used for the build.

## Modding Tips
- **Custom Music**: Edit `fmtune_pointer_table` / sequences. Add notes via freq tables; test envelopes for vibrato.
- **New SFX**: Add to `sfx_pointer_table`, create handler (init channels, YM writes), cmdstream (.bin), PCM if needed.
- **Testing**: Build `dev` for no checksum lock. Monitor shared RAM ($FFFFFE40+) for channel states.
