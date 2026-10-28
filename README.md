# NHL92Genesis

> **📀 Game data is not included.** This repository has the assembly code only. The graphics, palettes, EA logo, sound samples and sound effects are extracted from your own copy of the original ROM when you build, and are not in the repo. You need the retail NHL Hockey (NHL 92) Genesis ROM (and the Rev A ROM for that build), with the file names and SHA-1s listed under [Instructions](#instructions), or the build stops.

> **🤝 Making a mod, hack, port or other derivative work from this repo? You must credit me and everyone credited in this repo, clearly, in your own repo and in every release. See [Credits and derivative works](#credits-and-derivative-works).**

Bitwise perfect compilable assembly of NHL Hockey (aka NHL 92) for Sega Genesis. Includes fully disassembled sound driver. Requires original ROM file to build.

Built on the work that McMarkis (https://github.com/Mhopkinsinc/NHLHockey) did to get the code compiling.

## Features of this version:
- Retail version is bitwise perfect with retail ROM. Rev A build is bitwise perfect with the Rev A ROM. Both are verified by the build.
- Documentation of all File Formats used within the game
- Script which changes opcodes to match the custom compiler EA used to build the game
- Disassembled Retail Validation Check code included via checksum env variable
- Env vars allows build of Retail version (includes validation code), Rev A "retail" version (includes validation code) or Rev A Dev version (no validation code)
- Script to generate CRC16 Checksum used in ROM Header & CRC32 Checksum used in Validation code
- EA Logo code is disassembled and buildable
- Sound Driver code is disassembled and buildable
- Z80 sound driver is real, commented Z80 source (`src/sound/z80_snd_drv.asm`), assembled with asm80 and checked byte-for-byte against the ROM
- Script to extract assets from retail rom (Graphics, PCM audio, FM audio, and the Z80 driver bytes the build checks its assembled driver against), run automatically by the build when `Extracted/` is missing or incomplete
- Requires retail ROM

## Instructions

1. Install node from https://nodejs.org/en/download if it isn't already installed on your machine

2. In the `NHL92Genesis` folder, run `npm i`. This also installs [asm80](https://www.npmjs.com/package/asm80) (pinned in `package.json`, MIT, pure JavaScript), the Z80 assembler used for the Z80 sound driver; nothing else needs installing for it on Windows, Linux or macOS. The 68000 assembler (`assembler/Assembler.exe`, SNASM68k) runs directly on Windows and under wine on Linux/macOS.

3. Copy your NHL Hockey (NHL 92) Sega Genesis ROM dumps into the `NHL92Genesis` folder (ROMs are not included in the repo). The usual file names are below, but any file name works: the build finds each ROM by its SHA-1 and size (`tools/roms.js`):

    | ROM | File name | SHA-1 | Size |
    |---|---|---|---|
    | Retail (1991.MAY, GM T-50236 -00) | `nhl92retail.bin` (usual name) | `2337ad3c065f46edccf19007d7a5be80a97520d5` | 524288 bytes (512 KB) |
    | Rev A | `nhl92retailRevA.bin` (usual name) | `10b50ebf3db0b4d207e21acf4481eb704b3c45f9` | 524288 bytes (512 KB) |

    The assets can be extracted from either ROM (both give identical assets). The retail build is verified against the retail ROM and the Rev A build against the Rev A ROM; the dev build needs either one.

4. Build one of 3 versions. Everything runs through `tools/build.js` (node; on Windows it runs the assembler directly, on Linux/macOS under wine). Each build first runs `tools/prebuild.js`, which checks the ROM(s) by SHA-1 and size (and stops with the expected file name, SHA-1 and size if one is missing or wrong), then extracts the assets into `Extracted/` from that ROM with `tools/extractAssets92.js` if they are missing or incomplete. It then builds the EA logo (`output/<mode>/obj/modified_EALogo.bin`), the Z80 sound driver (`output/<mode>/obj/z80_snd_drv.bin`) and the sound driver (`output/<mode>/obj/modified_Hockey.snd`) before the main ROM.

    - `npm run build:retail`: the `Retail` ROM, with the retail checksum validation check. Verified against `nhl92retail.bin`
    - `npm run build:reva`: the `Rev A` ROM, with the checksum validation check. Verified against `nhl92retailRevA.bin`
    - `npm run build:dev`: for developing your own version. Uses `Rev A` flags without the checksum validation check

    Each version has its own folder: the built ROM is `output/retail/nhl92.bin`, `output/reva/nhl92.bin` or `output/dev/nhl92.bin`, and that folder's `obj/` holds the intermediates (modified logo and sound binaries, assembler logs and listings). `src/main.asm` and `src/hockey.asm` pick the right `obj/` files from the `MODE` equate that `build.js` passes to the assembler (0 retail, 1 Rev A, 2 dev). Both the retail and Rev A builds are verified byte for byte against their ROMs.

Other scripts:
- `npm run assets`: ROM check and asset extraction only (`npm run extractassets` runs the extractor directly)
- `npm run build:logo` / `npm run build:sound`: build only the EA logo or the sound driver (`build:sound` also assembles the Z80 driver)
- `npm run checksum`: print the header and validation checksums of `output/retail/nhl92.bin`, or of the ROM given as argument (`tools/generateChecksum.js`)
- `npm run clean`: delete `output/` and `Extracted/` (re-extracted by the next build)
- `tools/verify_all.sh`: extracts fresh and builds retail and Rev A, printing MATCH for each
- Add `--verbose` to `node tools/build.js ...` for the full tool output

All the build tools are in `tools/`.

## Build steps explained

`tools/build.js` prints one line per step with a short note under it, and the step's result under that:

1. **prebuild**: check the retail (or Rev A) ROM and extract graphics/sound assets into `Extracted/`.
2. **logo**: SNASM68k builds the EA logo intro (`output/<mode>/obj/modified_EALogo.bin`), then its opcodes are patched.
3. **z80**: asm80 assembles the Z80 sound driver `src/sound/z80_snd_drv.asm` into `output/<mode>/obj/z80_snd_drv.bin` (asm80 writes its listing `z80_snd_drv.lst` next to it) and checks it byte-for-byte against the retail driver bytes ($116A6-$11C3D), which the prebuild extracts to `Extracted/Sound/z80_snd_drv.bin` only for this check. `src/sound/sound.asm` includes this assembled file at `Z80_Program_Code`.
4. **sound**: SNASM68k builds the sound driver and music (`output/<mode>/obj/modified_Hockey.snd`), then its opcodes are patched.
5. **assemble**: SNASM68k turns `src/hockey.asm`, with the logo and sound, into a raw ROM image.
6. **fixopcodes**: patch the instructions where SNASM picks a different encoding than EA's original assembler.
7. **verify**: compare byte-for-byte with the retail or Rev A ROM. Dev builds are not verified.

In a terminal, each step turns a spinner while it runs and is redrawn with a green check or a red cross when it ends. Values are bold, `OK` and `MATCH` are green, and failures are red. The colours are off when the output is not a terminal, with `NO_COLOR` set, or with `--no-color`.

A failing step prints `FAILED` (or `MISMATCH`), the relevant log lines (`output/<mode>/obj/Build_nhl92.log` for the assembler) and `BUILD FAILED at <step>`, and exits 1. `npm run clean` reports what it removed from `output/` and `Extracted/`.

# Documentation

The documentation lives in [`docs/`](docs/README.md):

- [Retail vs Rev A](docs/retail-vs-reva.md): what differs between the two ROM versions and what `REV` changes
- [Sound system](docs/sound-system.md): the 68000 and Z80 drivers, SFX and music data, instrument patches
- [File formats](docs/file-formats.md): `.JIM`, `.ANIM` and `.PAL`
- [Modding](docs/modding.md): developing on this build, known issues, tips
- [EA's original documents](docs/original/README.md): the 1990-91 design review, ROM map update, password logic, sound effect lists and sine table

## AI assistance

This project is AI-assisted. The work is directed by a strict ruleset and curated by hand, with the aim of producing correctly labelled and commented code that matches the spirit of what the original source code would have been. We can't guarantee it's perfect, and ultimately this will always be a work in progress. If you see something that needs fixing, raise an issue, or even better, raise a PR.

## Credits and derivative works

Thanks to McMarkis (Mhopkinsinc), whose NHLHockey source this build is built on.

And thank you to the [original developers of the game](https://www.mobygames.com/game/8314/nhl-hockey/credits/).

This project is the result of my work and the work of the people credited above. If you build anything from it, including mods, ROM or EXE hacks, ports, released forks, tools, or any other derivative work, you must credit us:

- Put the credit in your repo's README, near the top and not buried in a footer, and in the notes of every release you publish, including any text file shipped inside a release archive.
- Name me and link to this repository.
- Name everyone credited here: McMarkis (Mhopkinsinc).
- If you only use part of this repo (docs, a tool, labels, a file format description), the credit still applies.
- If you are unsure, over-credit.

Credit is the condition for using this work. Please do not release a derivative without it.
