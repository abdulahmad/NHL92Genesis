# EA's Original Documents

Design and data documents that came with the original source, from the 1990-91 development of the Genesis hockey game (the game that shipped as *NHL Hockey*, or NHL 92). They used to sit in `src/_docs/` as plain text files; they are converted to Markdown here with the content unchanged.

| Document | Date | What it is |
|---|---|---|
| [Technical design review](technical-design-review.md) | 11/1990 | The plan: team, schedule, memory budget and memory maps, the seven milestones, graphics budget (sprite animation list, screens) and sound requirements |
| [ROM map and size estimate update](rom-map-update.md) | 3/13/1991 | A mid-project revision of the graphics size estimates (350k, down from 393k) |
| [Password logic](password-logic.md) | | How the playoff password is encoded, with the bracket bit layout |
| [Sound effect numbers](sound-effect-list.md) | | The sound effect and music numbering the sound driver's labels follow |
| [Sound effect numbers, early draft](sound-effect-list-early.md) | | The earlier draft; `src/ram.asm` still uses its names |
| [Sine table](sine-table.md) | | A 256-entry sine lookup table (`SINTAB.ASM`). It is not part of the build |
