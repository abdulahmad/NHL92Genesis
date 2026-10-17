# Sound Effect Numbers for Sega Hockey (early draft)

The earlier draft of [the sound effect list](sound-effect-list.md). It differs in three places: it lacks the note about skating sounds, SFX 1-4 are `beep1`, `beep2`, `sam_newcheck1` and `sam_newcheck2` (later `skating1`-`skating4`), and SFX 31 is `sam_ohh`. The `SFX...` equates in `src/ram.asm` (`SFXbeep1`, `SFXbeep2`, `SFXcheck2`, `SFXoooh`) match this draft's era. Converted from `src/_docs/TABLE.DOC`.

> USE HIT (CHECK) SOUNDS SPARINGLY.
> USE LOTS OF PUCK SOUNDS (passing,slaps ).

## Sound effect numbers

| # | Name | Description |
|---:|---|---|
| 0 | `siren` | FM siren |
| 1 | `beep1` | FM beep low pitch |
| 2 | `beep2` | FM beep high pitch |
| 3 | `sam_newcheck1` | sample new check sound 1 |
| 4 | `sam_newcheck2` | ditto lower pitch |
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
| 31 | `sam_ohh` | sample crowd oohhh ,(missed !) |

## Music numbers

| # | Music |
|---:|---|
| 0 | END OF PERIOD |
| 1 | SPLASH |
| 2 | (unused/reserved) |
| 3 | END OF GAME |
| 4 | PLAY OFF TREE SCREEN |
