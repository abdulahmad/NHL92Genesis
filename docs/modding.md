# Modding

Building your own version, known limitations and tips.

## Developing on this build
You need to build using `build:dev` to avoid the checksum validation. By default, this builds the `Rev A` version of the code. If for whatever reason, you do want to enforce checksum validation on your build, you need to use the `tools/generateChecksum.js` script (`npm run checksum`). Also, you need to do 2 passes of the script & updating the checksums to end up with the correct checksum for both CRC16 and CRC32. The game will not start if checksum validation is enabled and the checksum is incorrect.

## Known Issues/Limitations
- **PCM Overlaps**: Some FM patches overlap PCM (e.g., `sfx_oooh_pcm_ofs` = $10820). Modding may corrupt audio due to hardcoded address
- **Checksum Sensitivity**: Builds require exact extracts for bitwise match; minor ROM diffs break validation.
- **Z80 Sound Driver**: The Z80 driver is source in `src/sound/z80_snd_drv.asm`, assembled with asm80 (installed by `npm i`) as build step `z80`. The build stops if the result differs from the retail bytes, so a modded driver needs that check (`buildZ80` in `tools/build.js`) relaxed. FM patches live inside the driver (`z80_fm_patches`).

## Modding Tips
- **Custom Music**: Edit `fmtune_pointer_table` / sequences. Add notes via freq tables; test envelopes for vibrato.
- **New SFX**: Add to `sfx_pointer_table`, create handler (init channels, YM writes), cmdstream (.bin), PCM if needed.
- **Testing**: Build `dev` for no checksum lock. Monitor shared RAM ($FFFFFE40+) for channel states.
