# Expanding the ROM

`main` is a faithful disassembly of the retail cartridge: a stock build matches the retail 512 KB image. Changes a bigger ROM needs belong on a mod branch, not on `main`.

- `src/hockey.asm` fills to 512 KB with `dcb.b $80000-*,$FF` at the end, inside `IF CHECKSUM=1` together with `checksum.asm`. Code placed after that `ENDIF` starts at $80000 in a retail build. With `CHECKSUM=0` (`build:dev`) there is no fill, so the same code follows the last data directly. A larger image also needs the header ROM end ($1A4) and the boot checksum updated on a mod branch.

## Short jumps

### PC-relative branches (branch out of range)

SNASM's **Branch (n bytes) is out of range** is the ~±32 KB limit on **PC-relative** branches: **`bsr.w`**, **`bra.w`** and **`bxx.w`**. `tools/build.js` stops at the assemble step with `branch out of range` and points here.

Two patterns that break mod builds:

1. **New ROM inserted between existing modules.** Later files move forward in the image. Retail code may already branch with `.w` into a module far enough away that a few hundred bytes of insert pushes the branch past the limit. Put new code and data after the 512 KB fill in `src/hockey.asm` instead.
2. **Hooks into post-fill code.** Includes after the 512 KB fill in `src/hockey.asm` start at $80000. Any call from retail code into that region needs **`jsr (label).l`** / **`jmp (label).l`**. Code in the new region should not **`bsr.w`** distant retail helpers (for example shared `rts` labels); use **`.l`** calls or a **local `rts`**.

When the build prints branch out of range, fix placement and call mode using this section before changing unrelated branches.
