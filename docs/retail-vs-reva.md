# Retail (REV=0) vs Rev A (REV=1)

How the two shipped versions of the ROM differ, and what the `REV` build flag changes in the source.

The original source code that was released was in a state that was post-retail code, and had some fixes (which are mentioned down below). I'm not sure if this is an undumped late print run retail version, but it might be. As such, I've resorted to calling this newly discovered version of NHL92 `Rev A`.

## Overall Differences Between Retail (REV=0) vs Rev A (REV=1)
- **Bug Fixes Focus**: `Rev A` adds safeguards against crashes (e.g., extra RAM clearing, SR register settings), sound glitches (e.g., explicit crowd sound kills), and logic errors (e.g., bitmasking in playoff resolution to prevent overflow or invalid states). It also includes minor UI/alignment tweaks (e.g., different padding bytes or string parameters).
- **No Major Features Added**: Changes are subtle; no new gameplay mechanics, graphics, or levels. Rev=1 seems like a post-release patch for stability, especially in playoff modes and demo/initialization sequences.
- **Performance/Stability**: Extra RAM clears and SR (Status Register) manipulations suggest fixes for undefined behavior or memory corruption in `Retail`. Sound-related calls (e.g., `KillCrowd`) likely fix lingering audio issues.
- **Size/Alignment**: Some differences are padding bytes (e.g., `$E7` vs `$FF`), possibly to adjust ROM checksums, alignment, or fix disassembly issues in tools/compilers.
- **Playoff Logic**: `Rev A` adds bitmasking to ensure valid states in playoff trees, preventing progression bugs (e.g., infinite loops or invalid wins).
- **Total Changes**: About 10 distinct conditional blocks, mostly small (1-10 lines each). Rev=1 is "heavier" on initialization and error handling.

## Specific Differences and Comments

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
