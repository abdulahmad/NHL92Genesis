# NHL92Genesis Documentation

Start with the [main README](../README.md) for what this project is and how to build it.

## About this build

- [Retail vs Rev A](retail-vs-reva.md): how the two ROM versions differ and what the `REV` flag changes in the source
- [Modding](modding.md): developing on this build (checksum validation), known issues, tips

## How the game works

- [Sound system](sound-system.md): the 68000 and Z80 drivers, SFX and music data, instrument patches
- [Z80 sound driver listing](z80_snd_drv.lst): an older IDA-style listing of the Z80 driver, kept for reference only. It does not match the actual bytes in several places; the real source is [`src/sound/z80_snd_drv.asm`](../src/sound/z80_snd_drv.asm), which the build assembles
- [File formats](file-formats.md): `.JIM`, `.ANIM` and `.PAL`

## EA's original documents

The 1990-91 design documents, converted from plain text. See [the index](original/README.md).

- [Technical design review](original/technical-design-review.md)
- [ROM map and size estimate update](original/rom-map-update.md)
- [Password logic](original/password-logic.md)
- [Sound effect numbers](original/sound-effect-list.md) ([early draft](original/sound-effect-list-early.md))
- [Sine table](original/sine-table.md)
