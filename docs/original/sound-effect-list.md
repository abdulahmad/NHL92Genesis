# Sound Effect Numbers for Sega Hockey

EA's later sound effect and music list for the Genesis hockey game. The SFX equates at the top of [`src/sound/sound.asm`](../../src/sound/sound.asm) and the driver's handler, command stream and PCM names follow it. Converted from `src/_docs/SOUNDTAB.DOC`; the earlier draft is [sound-effect-list-early.md](sound-effect-list-early.md).

The list stops at 30. The game also has SFX 31 (`oooh`, a crowd oooh; `sam_ohh` in the early draft) and plays 32-34 as duplicates of 30. The game's own `SFX...` equates in `src/ram.asm` still use names from the early draft (`SFXbeep1`, `SFXbeep2`, `SFXcheck2`).

> USE HIT (CHECK) SOUNDS SPARINGLY.
> USE LOTS OF PUCK SOUNDS (passing,slaps ).
> The skating sounds might work,we need to try and see.(Rich wanted skating sounds)

## Sound effect numbers

| # | Name | Description |
|---:|---|---|
| 0 | `siren` | FM siren |
| 1 | `skating1` | FM skate and stop short |
| 2 | `skating2` | FM skate and stop short |
| 3 | `skating3` | FM skating turn short |
| 4 | `skating4` | FM skating turn short |
| 5 | `hitpuck` | FM hit puck |
| 6 | `hitboard` | FM hit board  loud |
| 7 | `hitboard2` | FM hit board lower pitch loud |
| 8 | `puck_faceoff` | FM puck hits ice on face off |
| 9 | `bounce_goal` | FM puck bounce off goal post |
| 10 | `whistle` | FM whistle |
| 11 | `sam_pass1` | sample pass shot #1 |
| 12 | `sam_pass2` | sample pass shot #2  more beef |
| 13 | `sam_puck2_slap` | sample slap shot |
| 14 | `whiff shotFM` | FM whiff (miss puck on slap shot) |
| 15 | `sam_hitboard1` | sample player hits boards 1 |
| 16 | `sam_hitboard2` | ditto at different playback rate |
| 17 | `sam_hitboard3` | ditto at different playback rate |
| 18 | `sam_hit1` | sample player hits(checks) another player 1 |
| 19 | `sam_hit2` | ditto at different playback rate |
| 20 | `sam_hit3` | ditto at different playback rate |
| 21 | `sam_punch1` | sample fighting punch sound |
| 22 | `sam_punch2` | ditto at different playback rate |
| 23 | `sam_punch3` | ditto at different playback rate |
| 24 | `foghorn` | FM fog horn end of period |
| 25 | `sam_crowdgoal` | sample crowd cheer |
| 26 | `sam_booing` | sample short booing |
| 27 | `hitboardvolm` | hit board1 medium volume |
| 28 | `hitboardvols` | hit board1 softer volume |
| 29 | `hitboard2volm` | hit board2 medium volume |
| 30 | `hitboard2vols` | hit board2 softer volume |

## Music numbers

| # | Music |
|---:|---|
| 0 | END OF PERIOD |
| 1 | SPLASH |
| 2 | (unused/reserved) |
| 3 | END OF GAME |
| 4 | PLAY OFF TREE SCREEN |
