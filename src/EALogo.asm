; ===========================================================================
; EALogoEntry: Entry point for the EA logo animation sequence
; Initializes and controls the EA logo animation, where the ECA letters flip
; into place (green E, yellow C, blue A) and the "ELECTRONIC ARTS" wordmark
; slides in from both sides, starting green, changing to match each letter's
; color, and fading out.
; ===========================================================================

; NextProgramSection = $E5E

VDP_DATA = $C00000
VDP_CTRL = $C00004

AnimationCompleteFlag = $FFC000
AnimationFrameCounter = $FFC002
AnimationPhase = $FFC004
AnimationTimer = $FFC006
AnimationMask = $FFC008
LetterCounter = $FFC00C

Controller1Input = $FFC00E
Controller2Input = $FFC010

ELetterWordmarkData = $FFC012
ELetterSpriteData = $FFC036
CLetterWordmarkData = $FFC0A2
CLetterSpriteData = $FFC0C6
ALetterWordmarkData = $FFC05A
ALetterSpriteData = $FFC07E

LogoGraphicsBuffer = $FFC0EA
WordmarkVRAMBuffer = $FFC9EA
WordmarkWorkBuffer = $FFC9F2
AnimationDataBuffer = $FFD2EA
LogoPaletteBuffer = $FFDBEA
TempPaletteBuffer = $FFE7EA

IO_CT1_DATA = $A10002
IO_CT2_DATA = $A10004
IO_CT1_CTRL = $A10008
IO_CT2_CTRL = $A1000A


EALogoEntry:
            bsr.w   ReadControllerInput ; Call subroutine to read controller input
            bsr.w   InitVDPForLogo     ; Initialize VDP for logo display
            bsr.w   ReadControllerInput ; Call controller input again (clear buffer)
            move.w  #0,(Controller1Input).l ; Clear controller 1 input buffer
            move.w  #0,(Controller2Input).l ; Clear controller 2 input buffer

; Wait for VDP vertical blank to ensure screen is ready for rendering
WaitVBlank:                             ; CODE XREF: EALogoEntry+12C↓j
            move.w  (VDP_CTRL).l,d0  ; Read VDP control port
            btst    #1,d0            ; Check vertical blank flag
            bne.s   WaitVBlank       ; Loop until vertical blank occurs
            move.w  #$8174,(VDP_CTRL).l ; Enable display (VDP register #1)

; Wait for VDP sprite processing completion
WaitSpriteProcessing:                  ; CODE XREF: EALogoEntry+140↓j
                                    ; EALogoEntry+16A↓j
            move.w  (VDP_CTRL).l,d1  ; Read VDP control port
            btst    #3,d1            ; Check sprite overflow flag
            bne.s   WaitSpriteProcessing ; Loop if sprite processing active
CheckSpriteProcessing:                 ; CODE XREF: EALogoEntry+14C↓j
            move.w  (VDP_CTRL).l,d1  ; Read VDP control port
            btst    #3,d1            ; Check sprite overflow flag
            beq.s   CheckSpriteProcessing ; Loop until sprite processing starts
            bsr.w   ReadControllerInput ; Read controller input
            andi.w  #$FF,d0          ; Mask controller 1 input
            bne.s   ExitLogoAnimation  ; Skip if input detected
            andi.w  #$FF,d1          ; Mask controller 2 input
            bne.s   ExitLogoAnimation  ; Skip if input detected
            bsr.w   AnimateEALogo      ; Call main logo animation subroutine
            cmpi.w  #0,(AnimationCompleteFlag).l ; Check if animation is complete
            beq.s   WaitSpriteProcessing ; Loop if animation not complete
ExitLogoAnimation:                     ; CODE XREF: EALogoEntry+156↑j
                                    ; EALogoEntry+15C↑j
            bra.w   NextProgramSection ; Jump to next program section
; End of function EALogoEntry

; ===========================================================================
; ReadControllerInput: Reads controller input
; Reads input from controllers 1 and 2, storing results in memory. Allows
; skipping the logo animation if a button is pressed.
; ===========================================================================
ReadControllerInput:                    ; CODE XREF: EALogoEntry↑p
                                    ; EALogoEntry+10E↑p ...
            move.b  #$40,(IO_CT1_CTRL+1).l ; Set controller 1 control port
            move.b  #0,(IO_CT1_DATA+1).l ; Clear controller 1 data
            move.w  #$A,d1           ; Set delay counter
DelayController1Read:                  ; CODE XREF: ReadControllerInput:DelayController1Read↓j
            dbf     d1,DelayController1Read ; Delay loop
            move.b  (IO_CT1_DATA+1).l,d0 ; Read controller 1 data
            asl.b   #2,d0            ; Shift bits for button mask
            andi.b  #$C0,d0          ; Mask Start/A buttons
            move.b  #$40,(IO_CT1_DATA+1).l ; Set controller 1 data
            move.w  #$A,d1           ; Set delay counter
DelayController1SecondRead:            ; CODE XREF: ReadControllerInput:DelayController1SecondRead↓j
            dbf     d1,DelayController1SecondRead ; Delay loop
            move.b  (IO_CT1_DATA+1).l,d1 ; Read controller 1 data
            andi.b  #$3F,d1          ; Mask directional buttons
            or.b    d1,d0            ; Combine button states
            not.b   d0               ; Invert for active-high logic
            move.w  d0,(Controller1Input).l ; Store controller 1 input
            move.b  #$40,(IO_CT2_CTRL+1).l ; Set controller 2 control port
            move.w  #$A,d1           ; Set delay counter
DelayController2Read:                  ; CODE XREF: ReadControllerInput:DelayController2Read↓j
            dbf     d1,DelayController2Read ; Delay loop
            move.b  #0,(IO_CT2_DATA+1).l ; Clear controller 2 data
            move.w  #$A,d1           ; Set delay counter
DelayController2SecondRead:            ; CODE XREF: ReadControllerInput:DelayController2SecondRead↓j
            dbf     d1,DelayController2SecondRead ; Delay loop
            move.b  (IO_CT2_DATA+1).l,d0 ; Read controller 2 data
            asl.b   #2,d0            ; Shift bits for button mask
            andi.b  #$C0,d0          ; Mask Start/A buttons
            move.b  #$40,(IO_CT2_DATA+1).l ; Set controller 2 data
            move.w  #$A,d1           ; Set delay counter
DelayController2ThirdRead:             ; CODE XREF: ReadControllerInput:DelayController2ThirdRead↓j
            dbf     d1,DelayController2ThirdRead ; Delay loop
            move.b  (IO_CT2_DATA+1).l,d1 ; Read controller 2 data
            andi.b  #$3F,d1          ; Mask directional buttons
            or.b    d1,d0            ; Combine button states
            not.b   d0               ; Invert for active-high logic
            move.w  d0,(Controller2Input).l ; Store controller 2 input
            move.w  d0,d1            ; Copy controller 2 input
            move.w  (Controller1Input).l,d0 ; Load controller 1 input
            rts                      ; Return
; End of function ReadControllerInput

; ===========================================================================
; AdjustWordmarkPosition: Adjusts wordmark sprite positions
; Manipulates sprite positions for the sliding "ELECTRONIC ARTS" wordmark
; during the animation, based on the current frame.
; ===========================================================================
AdjustWordmarkPosition:                ; CODE XREF: AnimateEALogo:SetupALetter↓p
            moveq   #$FFFFFFFC,d2    ; Set negative offset for sliding
            muls.w  d1,d2            ; Scale offset by animation frame
            moveq   #8,d0            ; Set loop counter (8 iterations)
UpdateWordmarkSprite:                  ; CODE XREF: AdjustWordmarkPosition+10↓j
            add.w   d2,(a0)          ; Adjust sprite position
            move.w  (a0)+,(a5)       ; Write position to VDP data
            add.w   d2,(a0)          ; Adjust next sprite position
            move.w  (a0)+,(a5)       ; Write position to VDP data
            add.w   d1,d2            ; Increment offset for next iteration
            dbf     d0,UpdateWordmarkSprite ; Loop for 8 iterations
            rts                      ; Return
; End of function AdjustWordmarkPosition

; ===========================================================================
; UpdateSpritePalette: Updates sprite palette for color changes
; Changes sprite palette indices to transition colors (green to yellow to blue)
; for the ECA letters and wordmark during the animation.
; ===========================================================================
UpdateSpritePalette:                   ; CODE XREF: AnimateEALogo:SetupELetter↓p
                                    ; AnimateEALogo:SetupCLetter↓p
            moveq   #$11,d0          ; Set loop counter (18 sprites)
ProcessSpritePalette:                  ; CODE XREF: UpdateSpritePalette+C↓j
            move.w  (a0)+,d2         ; Read sprite attribute
            andi.w  #$EFFF,d2        ; Clear palette index bits
            or.w    d1,d2            ; Set new palette index (color)
            move.w  d2,(a5)          ; Write to VDP data
            dbf     d0,ProcessSpritePalette ; Loop for 18 sprites
            rts                      ; Return
; End of function UpdateSpritePalette

; ===========================================================================
; PositionELetter: Adjusts sprite positions for E letter
; Sets sprite positions for the green E letter as it flips into place.
; ===========================================================================
PositionELetter:                       ; CODE XREF: AnimateEALogo+2EC↓p
            movem.w d0-d7,-(sp)      ; Save registers
            move.w  d3,d4            ; Copy base position
            addi.w  #$20,d3          ; Add offset for right side
            moveq   #$20,d5          ; Set width (32 pixels)
            sub.w   d1,d5            ; Adjust for animation frame
            asr.w   #1,d5            ; Divide by 2 for centering
            add.w   d5,d4            ; Adjust left position
            sub.w   d5,d3            ; Adjust right position
            addi.w  #$80,d4          ; Add screen offset (left)
            addi.w  #$80,d3          ; Add screen offset (right)
            moveq   #8,d0            ; Set loop counter (9 sprites)
WriteELetterPositions:                 ; CODE XREF: PositionELetter+22↓j
            move.w  d4,(a5)          ; Write left position to VDP
            move.w  d3,(a5)          ; Write right position to VDP
            dbf     d0,WriteELetterPositions ; Loop for 9 sprites
            movem.w (sp)+,d0-d7      ; Restore registers
            rts                      ; Return
; End of function PositionELetter

; ===========================================================================
; PositionALetter: Adjusts sprite positions for A letter
; Sets sprite positions for the blue A letter as it flips into place.
; ===========================================================================
PositionALetter:                       ; CODE XREF: AnimateEALogo+32A↓p
            movem.w d0-d7,-(sp)      ; Save registers
            move.w  d3,d4            ; Copy base position
            addi.w  #$20,d3          ; Add offset for right side
            addi.w  #$80,d4          ; Add screen offset (left)
            addi.w  #$80,d3          ; Add screen offset (right)
            moveq   #8,d0            ; Set loop counter (9 sprites)
WriteALetterPositions:                 ; CODE XREF: PositionALetter+18↓j
            move.w  d4,(a5)          ; Write left position to VDP
            move.w  d3,(a5)          ; Write right position to VDP
            dbf     d0,WriteALetterPositions ; Loop for 9 sprites
            movem.w (sp)+,d0-d7      ; Restore registers
            rts                      ; Return
; End of function PositionALetter

; ===========================================================================
; UpdateSpriteTiles: Updates sprite tile indices
; Updates tile indices for the ECA letters and wordmark during animation.
; ===========================================================================
UpdateSpriteTiles:                     ; CODE XREF: AnimateEALogo+300↓p
                                    ; AnimateEALogo+340↓p ...
            movem.w d1-d3,-(sp)      ; Save registers
            ori.w   #$C00,d2         ; Set high-priority sprite flag
            ori.w   #$C00,d3         ; Set high-priority sprite flag
            bra.s   WriteSpriteTileIndices ; Jump to loop
WriteTileIndex:                        ; CODE XREF: UpdateSpriteTiles:WriteSpriteTileIndices↓j
            move.w  d2,(a5)          ; Write tile index to VDP
            addq.w  #1,d2            ; Increment tile index
            move.w  d2,(a5)          ; Write next tile index
            addq.w  #1,d2            ; Increment tile index
WriteSpriteTileIndices:                ; CODE XREF: UpdateSpriteTiles+C↑j
            dbf     d1,WriteTileIndex ; Loop for d1 iterations
            move.w  d2,(a5)          ; Write final tile index
            move.w  d3,(a5)          ; Write final tile index
            movem.w (sp)+,d1-d3      ; Restore registers
            rts                      ; Return
; End of function UpdateSpriteTiles

; ===========================================================================
; AnimateEALogo: Main EA logo animation routine
; Orchestrates the flipping of ECA letters and sliding of the wordmark, handling
; sprite positions, palette changes, and animation timing.
; ===========================================================================
AnimateEALogo:                         ; CODE XREF: EALogoEntry+15E↑p
            tst.w   (AnimationCompleteFlag).l ; Check if animation is complete
            bne.s   ExitAnimation         ; Exit if complete
            tst.w   (AnimationFrameCounter).l ; Check animation frame counter
            blt.w   UpdateAnimationTimer   ; Skip if negative
            move.w  (AnimationFrameCounter).l,d0 ; Load frame counter
            subq.w  #1,(AnimationFrameCounter).l ; Decrement frame counter
            move.w  d0,d1            ; Copy frame counter
            neg.w   d0               ; Negate for sliding effect
            move.l  #$60000000,(VDP_CTRL).l ; Set VDP to sprite table
            moveq   #$6F,d2          ; Set loop counter (112 sprites)
WriteSpritePositions:                  ; CODE XREF: AnimateEALogo+3A↓j
            move.w  d0,(a5)          ; Write sprite Y position
            move.w  #$140,(a5)       ; Write sprite size/link
            move.w  d1,(a5)          ; Write sprite X position
            move.w  #$140,(a5)       ; Write sprite tile index
            dbf     d2,WriteSpritePositions ; Loop for 112 sprites
UpdateAnimationTimer:                  ; CODE XREF: AnimateEALogo+E↑j
            subq.w  #1,(AnimationTimer).l ; Decrement animation timer
            bge.w   FinalizeAnimation     ; Skip if timer not expired
            move.w  #1,(AnimationTimer).l ; Reset timer
            tst.w   (AnimationPhase).l ; Check animation phase
            bne.s   AdvanceAnimationPhase  ; Skip if not initial phase
            tst.w   (AnimationFrameCounter).l ; Check frame counter
            bge.s   AdvanceAnimationPhase  ; Skip if not negative
            st      (AnimationCompleteFlag).l ; Mark animation complete
ExitAnimation:                         ; CODE XREF: AnimateEALogo+6↑j
            moveq   #$FFFFFFFF,d0    ; Set return value
            rts                      ; Return
AdvanceAnimationPhase:                 ; CODE XREF: AnimateEALogo+56↑j
                                    ; AnimateEALogo+5E↑j
            addq.w  #1,(AnimationPhase).l ; Increment animation phase
            move.w  (AnimationPhase).l,d7 ; Load animation phase
            lea     (AnimationDataBuffer).l,a3 ; Load animation data
            move.w  #$23F,d0         ; Set loop counter (576 longs)
            move.l  #$49200001,(VDP_CTRL).l ; Set VDP to VRAM
TransferAnimationData:                 ; CODE XREF: AnimateEALogo+8C↓j
            move.l  (a3)+,(a5)       ; Write animation data to VDP
            dbf     d0,TransferAnimationData ; Loop for 576 longs
            cmp.w   #$18,d7          ; Check if phase > 24
            ble.s   SetupLetterAnimation  ; Continue if <= 24
            clr.w   (AnimationPhase).l ; Reset animation phase
            addq.w  #1,(LetterCounter).l ; Increment letter counter (E, C, A)
            cmpi.w  #2,(LetterCounter).l ; Check if all letters done
            ble.w   FinalizeAnimation     ; Continue if not
            clr.w   (LetterCounter).l ; Reset letter counter
            move.w  #$50,(AnimationTimer).l ; Set fade-out timer
            bra.w   FinalizeAnimation     ; Jump to end
SetupLetterAnimation:                  ; CODE XREF: AnimateEALogo+94↑j
            move.l  #$40000003,(VDP_CTRL).l ; Set VDP to CRAM
            move.w  #$8F08,(a4)      ; Set auto-increment
            cmp.w   #$D,d7           ; Check if phase >= 13
            bge.w   HandleColorChange     ; Handle color change
            cmp.w   #7,d7            ; Check if phase == 7
            bne.w   SetPaletteFlag        ; Skip if not
            move.w  #$1000,d1        ; Set palette index (green)
            cmpi.w  #0,(LetterCounter).l ; Check if E letter
            bne.s   SetupCLetter          ; Handle C or A
            move.l  #$C00C0000,(VDP_CTRL).l ; Set VRAM address for E
            move.w  #$A0,(a5)        ; Write tile index (E)
            move.l  #$C0080000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$A0,(a5)        ; Write tile index
            move.l  #$C00A0000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$4E4,(a5)       ; Write tile index (green E)
            lea     (ELetterSpriteData).l,a0 ; Load E sprite data
            move.w  #$5C04,(VDP_CTRL).l ; Set sprite table address
            bra.s   SetupELetter          ; Update palette
SetupCLetter:                          ; CODE XREF: AnimateEALogo+EA↑j
            cmpi.w  #1,(LetterCounter).l ; Check if C letter
            bne.s   SetupALetter          ; Handle A
            move.l  #$C0140000,(VDP_CTRL).l ; Set VRAM address for C
            move.w  #$A42,(a5)       ; Write tile index (yellow C)
            move.l  #$C01A0000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$A42,(a5)       ; Write tile index
            move.l  #$C0060000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$E86,(a5)       ; Write tile index (yellow C)
            lea     (CLetterSpriteData).l,a0 ; Load C sprite data
            move.w  #$5C94,(VDP_CTRL).l ; Set sprite table address
            bra.s   SetupELetter          ; Update palette
SetupALetter:                          ; CODE XREF: AnimateEALogo+12E↑j
            move.l  #$C0160000,(VDP_CTRL).l ; Set VRAM address for A
            move.w  #$8A,(a5)        ; Write tile index (blue A)
            move.l  #$C01C0000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$8A,(a5)        ; Write tile index
            move.l  #$C0040000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$CE,(a5)        ; Write tile index (blue A)
            lea     (ALetterSpriteData).l,a0 ; Load A sprite data
            move.w  #$5D24,(VDP_CTRL).l ; Set sprite table address
SetupELetter:                          ; CODE XREF: AnimateEALogo+124↑j
                                    ; AnimateEALogo+168↑j
            bsr.w   UpdateSpritePalette ; Update sprite palette
SetPaletteFlag:                        ; CODE XREF: AnimateEALogo+DA↑j
            moveq   #$FFFFFFFF,d1    ; Set palette flag
            bra.w   ConfigureLetterSprites ; Continue animation
HandleColorChange:                     ; CODE XREF: AnimateEALogo+D2↑j
            cmp.w   #$14,d7          ; Check if phase == 20
            bne.w   SetAlternatePaletteFlag ; Skip if not
            moveq   #0,d1            ; Clear palette index
            cmpi.w  #0,(LetterCounter).l ; Check if E letter
            bne.s   UpdateCLetter         ; Handle C or A
            move.l  #$C00C0000,(VDP_CTRL).l ; Set VRAM address for E
            move.w  #$4E4,(a5)       ; Write tile index (green E)
            move.l  #$C0080000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$8E8,(a5)       ; Write tile index
            move.l  #$C00A0000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$A0,(a5)        ; Write tile index
            lea     (ELetterSpriteData).l,a0 ; Load E sprite data
            move.w  #$5C04,(VDP_CTRL).l ; Set sprite table address
            bra.s   UpdateELetter         ; Update palette
UpdateCLetter:                        ; CODE XREF: AnimateEALogo+1BE↑j
            cmpi.w  #1,(LetterCounter).l ; Check if C letter
            bne.s   UpdateALetter         ; Handle A
            move.l  #$C0140000,(VDP_CTRL).l ; Set VRAM address for C
            move.w  #$E86,(a5)       ; Write tile index (yellow C)
            move.l  #$C01A0000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$ECA,(a5)       ; Write tile index
            move.l  #$C0060000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$A42,(a5)       ; Write tile index
            lea     (CLetterSpriteData).l,a0 ; Load C sprite data
            move.w  #$5C94,(VDP_CTRL).l ; Set sprite table address
            bra.s   UpdateELetter         ; Update palette
UpdateALetter:                        ; CODE XREF: AnimateEALogo+202↑j
            move.l  #$C0160000,(VDP_CTRL).l ; Set VRAM address for A
            move.w  #$CE,(a5)        ; Write tile index (blue A)
            move.l  #$C01C0000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$8EE,(a5)       ; Write tile index
            move.l  #$C0040000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$8A,(a5)        ; Write tile index
            lea     (ALetterSpriteData).l,a0 ; Load A sprite data
            move.w  #$5D24,(VDP_CTRL).l ; Set sprite table address
UpdateELetter:                        ; CODE XREF: AnimateEALogo+1F8↑j
                                    ; AnimateEALogo+23C↑j
            bsr.w   UpdateSpritePalette ; Update sprite palette
SetAlternatePaletteFlag:               ; CODE XREF: AnimateEALogo+1B0↑j
            moveq   #1,d1            ; Set alternate palette flag
ConfigureLetterSprites:                ; CODE XREF: AnimateEALogo+1A8↑j
            cmpi.w  #0,(LetterCounter).l ; Check if E letter
            bne.s   ConfigureCLetter      ; Handle C or A
            move.w  #$5C00,(VDP_CTRL).l ; Set sprite table for E
            movea.l #ELetterWordmarkData,a0 ; Load E wordmark data
ConfigureCLetter:                      ; CODE XREF: AnimateEALogo+284↑j
            cmpi.w  #1,(LetterCounter).l ; Check if C letter
            bne.s   ConfigureALetter      ; Handle A
            move.w  #$5C90,(VDP_CTRL).l ; Set sprite table for C
            lea     (CLetterWordmarkData).l,a0 ; Load C wordmark data
ConfigureALetter:                      ; CODE XREF: AnimateEALogo+29C↑j
            cmpi.w  #2,(LetterCounter).l ; Check if A letter
            bne.s   UpdateWordmark        ; Skip if not
            move.w  #$5D20,(VDP_CTRL).l ; Set sprite table for A
            lea     (ALetterWordmarkData).l,a0 ; Load A wordmark data
UpdateWordmark:                        ; CODE XREF: AnimateEALogo+2B4↑j
            bsr.w   AdjustWordmarkPosition ; Update wordmark positions
            move.w  d7,d1            ; Copy animation phase
            ext.l   d1               ; Extend to long
            divu.w  #3,d1            ; Divide by 3 for timing
            cmpi.w  #0,(LetterCounter).l ; Check if E letter
            bne.s   ProcessALetter        ; Handle C or A
            move.w  d1,-(sp)         ; Save d1
            asl.w   #2,d1            ; Scale animation phase
            move.w  #$68,d3          ; Set base Y position
            sub.w   d7,d3            ; Adjust for animation
            move.w  #$5C06,(VDP_CTRL).l ; Set sprite table for E
            bsr.w   PositionELetter  ; Adjust E letter position
            move.w  (sp)+,d1         ; Restore d1
            moveq   #1,d2            ; Set tile index offset
            moveq   #$12,d3          ; Set tile index
            moveq   #0,d3            ; Clear d3
            move.w  #$5C02,(VDP_CTRL).l ; Set sprite table
            bsr.w   UpdateSpriteTiles ; Update sprite tiles
            move.w  #$4E4,d0         ; Set tile index (green E)
            bsr.w   UpdateLetterColor ; Update color
            bra.s   FinalizeLetterAnimation ; Continue
ProcessALetter:                        ; CODE XREF: AnimateEALogo+2D8↑j
            cmpi.w  #2,(LetterCounter).l ; Check if A letter
            bne.s   ProcessCLetter        ; Handle C
            move.w  d1,-(sp)         ; Save d1
            asl.w   #2,d1            ; Scale animation phase
            move.w  #$98,d3          ; Set base Y position
            add.w   d7,d3            ; Adjust for animation
            move.w  #$5D26,(VDP_CTRL).l ; Set sprite table for A
            bsr.w   PositionALetter  ; Adjust A letter position
            move.w  (sp)+,d1         ; Restore d1
            move.w  #$5D1A,(VDP_CTRL).l ; Set sprite table
            move.w  #$C24,(a5)       ; Write tile index
            moveq   #$25,d2          ; Set tile index offset
            moveq   #0,d3            ; Clear d3
            bsr.w   UpdateSpriteTiles ; Update sprite tiles
            move.w  #$CE,d0          ; Set tile index (blue A)
            bsr.w   UpdateLetterColor ; Update color
FinalizeLetterAnimation:               ; CODE XREF: AnimateEALogo+30C↑j
            bra.s   FinalizeAnimation ; Continue
ProcessCLetter:                        ; CODE XREF: AnimateEALogo+316↑j
            move.w  #$5C8A,(VDP_CTRL).l ; Set sprite table for C
            move.w  #$C12,(a5)       ; Write tile index
            moveq   #$13,d2          ; Set tile index offset
            moveq   #0,d3            ; Clear d3
            bsr.w   UpdateSpriteTiles ; Update sprite tiles
            move.w  #$E86,d0         ; Set tile index (yellow C)
            bsr.w   UpdateLetterColor ; Update color
            lea     (AnimationDataBuffer).l,a3 ; Load fade data
            moveq   #0,d2            ; Clear d2
            move.w  #$23F,d0         ; Set loop counter (576 longs)
ClearFadeData:                         ; CODE XREF: AnimateEALogo+378↓j
            move.l  d2,(a3)+         ; Clear fade data
            dbf     d0,ClearFadeData ; Loop for 576 longs
            add.w   d1,d1            ; Scale animation phase
            addq.w  #4,d1            ; Adjust phase
            cmp.w   #$10,d1          ; Check if phase > 16
            ble.s   SetupWordmarkFade     ; Continue if <= 16
            moveq   #$10,d1          ; Cap phase at 16
SetupWordmarkFade:                    ; CODE XREF: AnimateEALogo+384↑j
            moveq   #$20,d3          ; Set width (32 pixels)
            movea.w d3,a1            ; Copy width
            subq.w  #1,a1            ; Adjust width
            move.w  #$10,d0          ; Set max phase
            sub.w   d1,d0            ; Adjust for current phase
            add.w   d0,d3            ; Adjust width
            suba.w  d0,a1            ; Adjust width
            bsr.w   FadeWordmark      ; Update wordmark fade
FinalizeAnimation:                     ; CODE XREF: AnimateEALogo+44↑j
                                    ; AnimateEALogo+AA↑j ...
            move.w  #$8F02,(a4)      ; Restore auto-increment
            moveq   #0,d0            ; Clear return value
            rts                      ; Return
; End of function AnimateEALogo

; ===========================================================================
; UpdateWordmarkSpriteData: Updates wordmark sprite position and tiles
; Updates sprite positions and tile indices for the sliding wordmark.
; ===========================================================================
UpdateWordmarkSpriteData:                  ; CODE XREF: SetupWordmarkSprites:WriteSpriteData↓p
                                    ; SetupWordmarkSprites+6↓p ...
            move.w  #$80,(a0)        ; Set base X position
            add.w   d3,(a0)          ; Adjust X position
            move.w  (a0)+,(a5)       ; Write X position to VDP
            move.w  #$C00,d0         ; Set tile flag
            or.w    d1,d0            ; Add tile index
            addq.w  #1,d1            ; Increment tile index
            move.w  d0,(a5)          ; Write tile index to VDP
            move.w  #$8201,(a1)      ; Set base Y position
            add.w   d4,(a1)          ; Adjust Y position
            addq.w  #4,d4            ; Increment Y offset
            move.w  (a1)+,(a5)       ; Write Y position to VDP
            move.w  #$80,d0          ; Set base tile index
            add.w   d2,d0            ; Add tile offset
            rts                      ; Return
; End of function UpdateWordmarkSpriteData

; ===========================================================================
; SetupWordmarkSprites: Sets up wordmark sprite data
; Configures sprite data for the "ELECTRONIC ARTS" wordmark sliding effect.
; ===========================================================================
SetupWordmarkSprites:                  ; CODE XREF: EALogoGraphicsInit+16E↓p
                                    ; EALogoGraphicsInit+18C↓p ...
            moveq   #7,d7            ; Set loop counter (8 iterations)
WriteSpriteData:                       ; CODE XREF: SetupWordmarkSprites+10↓j
            bsr.s   UpdateWordmarkSpriteData ; Update sprite
            move.w  d0,(a5)          ; Write tile index
            bsr.s   UpdateWordmarkSpriteData ; Update next sprite
            addi.w  #$20,d0          ; Adjust tile index
            move.w  d0,(a5)          ; Write tile index
            addq.w  #6,d3            ; Adjust X position
            dbf     d7,WriteSpriteData ; Loop for 8 iterations
            bsr.s   UpdateWordmarkSpriteData ; Update final sprite
            move.w  d0,(a5)          ; Write tile index
            move.w  d5,d1            ; Copy tile index
            bsr.s   UpdateWordmarkSpriteData ; Update final sprite
            addi.w  #$20,d0          ; Adjust tile index
            move.w  d0,(a5)          ; Write tile index
            rts                      ; Return
; End of function SetupWordmarkSprites

; ===========================================================================
; CalculateWordmarkIndex: Calculates wordmark sprite indices
; Computes indices for wordmark sprite animation.
; ===========================================================================
CalculateWordmarkIndex:                ; CODE XREF: EALogoGraphicsInit:ProcessAnimationData↓p
                                    ; EALogoGraphicsInit+5A↓p
            move.w  d5,d6            ; Copy base index
            move.w  d4,d7            ; Copy offset
            asl.w   #2,d7            ; Scale offset
            add.w   d7,d6            ; Add to index
            rts                      ; Return
; End of function CalculateWordmarkIndex

; ===========================================================================
; PrepareAnimationData: Prepares sprite animation data
; Prepares data for sprite animation calculations.
; ===========================================================================
PrepareAnimationData:                  ; CODE XREF: ProcessSpriteAnimation+A↓p
                                    ; ProcessSpriteAnimation+1A↓p
            move.l  (AnimationMask).l,d3 ; Load animation mask
            move.l  d0,d5            ; Copy input
            swap    d5               ; Swap words
            move.w  d5,d4            ; Copy high word
            andi.w  #7,d5            ; Mask low bits
            asl.w   #2,d5            ; Scale for bit shift
            asr.w   #3,d4            ; Shift for tile index
            asl.w   #5,d4            ; Scale for VRAM offset
            rts                      ; Return
; End of function PrepareAnimationData

; ===========================================================================
; ProcessSpriteAnimation: Processes sprite animation data
; Handles sprite animation data for smooth transitions in the logo animation.
; ===========================================================================
ProcessSpriteAnimation:                ; CODE XREF: FadeWordmark+72↓p
                                    ; FadeWordmark+90↓p ...
            movem.l d0-d7,-(sp)      ; Save registers
            cmp.l   d1,d2            ; Compare animation bounds
            blt.s   ExitSpriteAnimation   ; Skip if out of bounds
            move.l  d2,d0            ; Copy bound
            bsr.s   PrepareAnimationData ; Prepare data
            move.l  d3,d6            ; Copy mask
            move.w  d4,d7            ; Copy tile offset
            subi.w  #$1C,d5          ; Adjust shift
            neg.w   d5               ; Negate shift
            asl.l   d5,d6            ; Shift mask
            move.l  d1,d0            ; Copy lower bound
            bsr.s   PrepareAnimationData ; Prepare data
            lsr.l   d5,d3            ; Shift mask
            cmp.w   d7,d4            ; Compare tile offsets
            bne.s   WriteTileMask         ; Handle different tiles
            and.l   d3,d6            ; Combine masks
            move.l  d6,(a6,d4.w)     ; Write to VRAM
            bra.s   ExitSpriteAnimation   ; Continue
WriteTileMask:                         ; CODE XREF: ProcessSpriteAnimation+20↑j
            move.l  d3,(a6,d4.w)     ; Write mask to VRAM
AdjustTileOffset:                      ; CODE XREF: ProcessSpriteAnimation+3E↓j
            addi.w  #$20,d4          ; Increment tile offset
            cmp.w   d4,d7            ; Check if done
            beq.s   WriteFinalMask        ; Exit loop
            move.l  (AnimationMask).l,(a6,d4.w) ; Write default mask
            bra.s   AdjustTileOffset      ; Continue loop
WriteFinalMask:                        ; CODE XREF: ProcessSpriteAnimation+34↑j
            move.l  d6,(a6,d7.w)     ; Write final mask
ExitSpriteAnimation:                   ; CODE XREF: ProcessSpriteAnimation+6↑j
                                    ; ProcessSpriteAnimation+28↑j
            movem.l (sp)+,d0-d7      ; Restore registers
            rts                      ; Return
; End of function ProcessSpriteAnimation

; ===========================================================================
; UpdateLetterColor: Updates color for ECA letters
; Updates colors for the ECA letters during flipping and fading.
; ===========================================================================
UpdateLetterColor:                     ; CODE XREF: AnimateEALogo+308↑p
                                    ; AnimateEALogo+348↑p ...
            cmp.w   #$18,d7          ; Check if phase == 24
            bne.s   ExitColorUpdate       ; Return if not
            move.l  #$C0120000,(VDP_CTRL).l ; Set VRAM address
            move.w  d0,(a5)          ; Write tile index
            move.l  #$C0020000,(VDP_CTRL).l ; Set VRAM address
            cmp.w   #$E86,d0         ; Check if yellow C
            bne.s   AdjustColorIndex      ; Skip if not
            move.w  #$E22,d0         ; Adjust tile index
AdjustColorIndex:                      ; CODE XREF: UpdateLetterColor+20↑j
            andi.w  #$666,d0         ; Mask color bits
            move.w  d0,(a5)          ; Write color
ExitColorUpdate:                       ; CODE XREF: UpdateLetterColor+4↑j
            rts                      ; Return
; End of function UpdateLetterColor

; ===========================================================================
; FadeWordmark: Handles wordmark fade-out effect
; Manages the fading out of the "ELECTRONIC ARTS" wordmark after animation.
; ===========================================================================
FadeWordmark:                         ; CODE XREF: AnimateEALogo+398↑p
            lea     WordmarkAnimationTable(pc),a0 ; Load animation table
            lea     (AnimationDataBuffer).l,a6 ; Load VRAM buffer
            lea     WordmarkFadeTable(pc),a2 ; Load fade data
            lea     WordmarkPositionTable(pc),a3 ; Load position data
            moveq   #0,d6            ; Clear counter
            moveq   #8,d4            ; Set loop counter (9 iterations)
ProcessFadeStep:                       ; CODE XREF: FadeWordmark+A2↓j
            move.b  (a0)+,d5         ; Read animation step
            ext.w   d5               ; Extend to word
            moveq   #5,d0            ; Set inner loop counter
ProcessFadeIteration:                  ; CODE XREF: FadeWordmark+98↓j
            move.l  #$AAAAAAAA,(AnimationMask).l ; Set default mask
            cmp.w   #$1B,d6          ; Check animation progress
            beq.s   AdjustFadePosition    ; Skip if at midpoint
            bgt.s   ReverseFadePosition   ; Handle reverse
            move.b  (a3)+,d7         ; Read forward position
            bra.s   AdjustFadePosition    ; Continue
ReverseFadePosition:                   ; CODE XREF: FadeWordmark+2C↑j
            move.b  -(a3),d7         ; Read reverse position
            neg.b   d7               ; Negate position
AdjustFadePosition:                    ; CODE XREF: FadeWordmark+2A↑j
                                    ; FadeWordmark+30↑j
            ext.w   d7               ; Extend to word
            sub.w   d7,d3            ; Adjust position
            adda.w  d7,a1            ; Adjust pointer
            addq.w  #1,d6            ; Increment counter
            tst.w   d5               ; Check animation step
            ble.s   HandleZeroStep        ; Handle zero/negative
            cmp.w   #1,d5            ; Check if step == 1
            bne.s   SetupFadeData         ; Skip if not
            move.l  #$33333333,(AnimationMask).l ; Set fade mask
SetupFadeData:                         ; CODE XREF: FadeWordmark+46↑j
            move.l  d3,d1            ; Copy position
            move.l  a1,d2            ; Copy pointer
            cmp.w   #5,d0            ; Check if final iteration
            bne.s   ApplyFadeData         ; Skip if not
            move.l  #$DDDDDDDD,(AnimationMask).l ; Set final mask
            cmp.w   #8,d1            ; Check position
            bge.s   ApplyFadeData         ; Skip if >= 8
            moveq   #8,d1            ; Set minimum position
ApplyFadeData:                         ; CODE XREF: FadeWordmark+5A↑j
                                    ; FadeWordmark+6A↑j
            swap    d1               ; Swap position
            swap    d2               ; Swap pointer
            bsr.w   ProcessSpriteAnimation ; Process animation data
            bra.s   AdvanceFadeBuffer      ; Continue
HandleZeroStep:                        ; CODE XREF: FadeWordmark+40↑j
            blt.s   AdvanceFadeBuffer      ; Skip if negative
            move.l  #$33333333,(AnimationMask).l ; Set fade mask
            move.l  d3,d1            ; Copy position
            move.b  (a2)+,d2         ; Read fade offset
            ext.w   d2               ; Extend to word
            add.w   d1,d2            ; Add to position
            swap    d1               ; Swap position
            swap    d2               ; Swap offset
            bsr.w   ProcessSpriteAnimation ; Process animation data
AdvanceFadeBuffer:                     ; CODE XREF: FadeWordmark+76↑j
                                    ; FadeWordmark:HandleZeroStep↑j
            addq.l  #4,a6            ; Advance VRAM buffer
            subq.w  #1,d5            ; Decrement step
            dbf     d0,ProcessFadeIteration ; Loop for 6 iterations
            adda.l  #$E8,a6          ; Advance VRAM buffer
            dbf     d4,ProcessFadeStep ; Loop for 9 iterations
            rts                      ; Return
; End of function FadeWordmark

; ===========================================================================
; InitVDPForLogo: Initializes VDP for logo animation
; Sets up VDP registers and clears VRAM for the EA logo display.
; ===========================================================================
InitVDPForLogo:                       ; CODE XREF: EALogoEntry+10A↑p
            clr.w   (AnimationCompleteFlag).l ; Clear animation flag
            movea.l #VDP_CTRL,a4     ; Set VDP control port
            movea.l #VDP_DATA,a5     ; Set VDP data port
            move.w  #$3FF6,d0        ; Set loop counter (16374 bytes)
            moveq   #0,d1            ; Clear d1
            movea.l #$FFFF0000,a0    ; Set RAM address
ClearRAMBuffer:                        ; CODE XREF: InitVDPForLogo+20↓j
            move.l  d1,(a0)+         ; Clear RAM
            dbf     d0,ClearRAMBuffer ; Loop for 16374 bytes
            movea.l #VDP_CTRL,a4     ; Set VDP control port
            movea.l #VDP_DATA,a5     ; Set VDP data port
            move.w  #$8004,(a4)      ; Set VDP register #0 (mode)
            move.w  #$8134,(a4)      ; Set VDP register #1 (display off)
            move.w  #$8228,(a4)      ; Set VDP register #2 (plane A)
            move.w  #$8330,(a4)      ; Set VDP register #3 (plane W)
            move.w  #$8405,(a4)      ; Set VDP register #4 (plane B)
            move.w  #$856E,(a4)      ; Set VDP register #5 (sprite table)
            move.w  #$8700,(a4)      ; Set VDP register #7 (background)
            move.w  #$8B03,(a4)      ; Set VDP register #11 (scroll)
            move.w  #$9003,(a4)      ; Set VDP register #16 (screen size)
            move.w  #$8C81,(a4)      ; Set VDP register #12 (mode)
            move.w  #$8D08,(a4)      ; Set VDP register #13 (H-scroll)
            move.w  #$8F02,(a4)      ; Set VDP register #15 (auto-inc)
            move.w  #$9100,(a4)      ; Set VDP register #17 (window H)
            move.w  #$9200,(a4)      ; Set VDP register #18 (window V)
            move.w  #$8A01,(a4)      ; Set VDP register #10 (H-int)
            move.l  #$40000000,(VDP_CTRL).l ; Set VRAM address
            move.w  #$3FFF,d1        ; Set loop counter (16383 longs)
            moveq   #0,d0            ; Clear d0
ClearVRAM:                             ; CODE XREF: InitVDPForLogo+7E↓j
            move.l  d0,(a5)          ; Clear VRAM
            dbf     d1,ClearVRAM     ; Loop for 16383 longs
            moveq   #0,d1            ; Clear d1
            move.l  #$40000010,(VDP_CTRL).l ; Set VRAM address
            bsr.s   EALogoGraphicsInit ; Initialize logo graphics
            move.l  #$60000000,(VDP_CTRL).l ; Set sprite table
            neg.w   d1               ; Negate d1
            rts                      ; Return
; End of function InitVDPForLogo

; ===========================================================================
; EALogoGraphicsInit: Initializes graphics for EA logo animation
; Loads and processes graphics data for the EA logo and wordmark, setting up
; sprites and palettes for the animation.
; ===========================================================================
EALogoGraphicsInit:                   ; CODE XREF: InitVDPForLogo+8E↑p
            move.w  d1,(a5)          ; Write initial sprite data
            move.w  d1,(a5)          ; Write initial sprite data
            lea     (LogoGraphicsBuffer).l,a3 ; Load graphics buffer
            move.w  #$20,d1          ; Set stride (32 bytes)
            moveq   #8,d0            ; Set loop counter (9 iterations)
            lea     WordmarkAnimationTable(pc),a0 ; Load animation table
            moveq   #0,d5            ; Clear counter
ProcessAnimationStep:                  ; CODE XREF: EALogoGraphicsInit+72↓j
            moveq   #0,d4            ; Clear offset
            moveq   #0,d2            ; Clear index
            move.b  (a0)+,d2         ; Read animation step
            bra.s   ProcessAnimationDataLoop  ; Process step
ProcessAnimationData:                  ; CODE XREF: EALogoGraphicsInit:ProcessAnimationStep↓j
            bsr.w   CalculateWordmarkIndex ; Calculate index
            movea.l #$66666666,a1    ; Set default pattern
            tst.w   d4               ; Check offset
            bne.s   SetPattern            ; Skip if non-zero
            movea.l #$44444444,a1    ; Set alternate pattern
SetPattern:                            ; CODE XREF: EALogoGraphicsInit+2A↑j
            moveq   #7,d7            ; Set loop counter (8 iterations)
WritePattern:                          ; CODE XREF: EALogoGraphicsInit+4C↓j
            tst.w   d2               ; Check animation step
            bne.s   ApplyPattern          ; Skip if non-zero
            cmpa.l  #$44444444,a1    ; Check pattern
            beq.s   ApplyPattern          ; Skip if default
            movea.l #$55555555,a1    ; Set blank pattern
ApplyPattern:                          ; CODE XREF: EALogoGraphicsInit+36↑j
                                    ; EALogoGraphicsInit+3E↑j
            move.l  a1,(a3,d6.w)     ; Write pattern to buffer
            add.w   d1,d6            ; Advance buffer
            dbf     d7,WritePattern  ; Loop for 8 iterations
            addq.w  #1,d4            ; Increment offset
ProcessAnimationDataLoop:              ; CODE XREF: EALogoGraphicsInit+1C↑j
            dbf     d2,ProcessAnimationData ; Loop for animation step
            tst.w   d0               ; Check if done
            beq.s   TransferGraphicsData  ; Exit if done
            bsr.w   CalculateWordmarkIndex ; Calculate index
            movea.l #$55555555,a1    ; Set blank pattern
            move.l  a1,(a3,d6.w)     ; Write pattern
            add.w   d1,d6            ; Advance buffer
            move.l  a1,(a3,d6.w)     ; Write pattern
            addi.w  #$100,d5         ; Increment counter
            dbf     d0,ProcessAnimationStep ; Loop for 9 iterations
TransferGraphicsData:                  ; CODE XREF: EALogoGraphicsInit+58↑j
            lea     (LogoGraphicsBuffer).l,a3 ; Load graphics buffer
            move.w  #$23F,d0         ; Set loop counter (576 longs)
            move.l  #$40200001,(VDP_CTRL).l ; Set VRAM address
WriteGraphicsData:                     ; CODE XREF: EALogoGraphicsInit+8C↓j
            move.l  (a3)+,(a5)       ; Write graphics to VDP
            dbf     d0,WriteGraphicsData ; Loop for 576 longs
            move.l  #$97B4,d6        ; Set data offset
            move.l  a4,-(sp)         ; Save a4
            movea.l d6,a3            ; Set data pointer
            lsr.w   #1,d6            ; Adjust offset
            lea     WordmarkAnimationTable(pc),a0 ; Load animation table
            lea     (WordmarkWorkBuffer).l,a6 ; Load VRAM buffer
            lea     WordmarkOffsetTable(pc),a4 ; Load wordmark data
            move.w  #$20,d3          ; Set stride (32 bytes)
            swap    d3               ; Swap stride
            movea.l d3,a2            ; Copy stride
            movea.l d3,a1            ; Copy stride
            moveq   #8,d4            ; Set loop counter (9 iterations)
ProcessWordmarkStep:                   ; CODE XREF: EALogoGraphicsInit+12C↓j
            move.b  (a0)+,d5         ; Read animation step
            ext.w   d5               ; Extend to word
            moveq   #5,d0            ; Set inner loop counter
ProcessWordmarkIteration:              ; CODE XREF: EALogoGraphicsInit+122↓j
            move.l  #$BBBBBBBB,(AnimationMask).l ; Set default mask
            tst.w   d5               ; Check animation step
            ble.s   HandleEmptyStep       ; Handle zero/negative
            cmp.w   #1,d5            ; Check if step == 1
            bne.s   SetWordmarkData       ; Skip if not
            move.l  #$22222222,(AnimationMask).l ; Set alternate mask
SetWordmarkData:                       ; CODE XREF: EALogoGraphicsInit+CE↑j
            cmp.w   #5,d0            ; Check if final iteration
            bne.s   ApplyWordmarkData     ; Skip if not
            move.l  #$EEEEEEEE,(AnimationMask).l ; Set final mask
ApplyWordmarkData:                     ; CODE XREF: EALogoGraphicsInit+DE↑j
            move.l  d3,d1            ; Copy position
            move.l  a1,d2            ; Copy pointer
            bsr.w   ProcessSpriteAnimation ; Process animation data
HandleEmptyStep:                       ; CODE XREF: EALogoGraphicsInit+C8↑j
            tst.w   d5               ; Check animation step
            bne.s   ProcessOffsetData     ; Skip if non-zero
            move.l  #$22222222,(AnimationMask).l ; Set alternate mask
            moveq   #0,d2            ; Clear index
            move.b  (a4)+,d2         ; Read wordmark offset
            beq.s   ApplyDefaultData      ; Skip if zero
            swap    d2               ; Swap offset
            add.l   d3,d2            ; Add position
            move.l  d3,d1            ; Copy position
            bsr.w   ProcessSpriteAnimation ; Process animation data
ApplyDefaultData:                      ; CODE XREF: EALogoGraphicsInit+104↑j
            move.l  a2,d1            ; Copy stride
            move.l  a1,d2            ; Copy pointer
            bsr.w   ProcessSpriteAnimation ; Process animation data
ProcessOffsetData:                     ; CODE XREF: EALogoGraphicsInit+F4↑j
            addq.l  #4,a6            ; Advance VRAM buffer
            subq.w  #1,d5            ; Decrement step
            sub.l   a3,d3            ; Adjust position
            adda.l  a3,a1            ; Adjust pointer
            adda.l  d6,a2            ; Adjust stride
            dbf     d0,ProcessWordmarkIteration ; Loop for 6 iterations
            adda.l  #$E8,a6          ; Advance VRAM buffer
            dbf     d4,ProcessWordmarkStep ; Loop for 9 iterations
            movea.l (sp)+,a4         ; Restore a4
            lea     (WordmarkVRAMBuffer).l,a3 ; Load VRAM buffer
            move.w  #$23F,d0         ; Set loop counter (576 longs)
            move.l  #$52200001,(VDP_CTRL).l ; Set VRAM address

; ===========================================================================
; Continuation of EALogoGraphicsInit: Initializes graphics for EA logo animation
; Loads and processes graphics data for the EA logo and wordmark, continuing
; from the previous cutoff. This section handles sprite and tile data setup for
; the ECA letters (green E, yellow C, blue A) and the sliding "ELECTRONIC ARTS"
; wordmark, which starts green and transitions to match each letter's color.
; ===========================================================================
WriteLogoGraphics:                      ; CODE XREF: EALogoGraphicsInit+148↑j
            move.l  (a3)+,(a5)       ; Write graphics data to VDP data port
            dbf     d0,WriteLogoGraphics ; Loop for 576 longs to transfer graphics data
            move.l  #$5C000003,(VDP_CTRL).l ; Set VDP to sprite table address
            lea     (ELetterWordmarkData).l,a0 ; Load sprite data for E letter wordmark
            lea     (ELetterSpriteData).l,a1 ; Load additional sprite data for E letter
            moveq   #1,d1            ; Set initial tile index for wordmark
            moveq   #$50,d2          ; Set X position offset (80 pixels) for wordmark
            move.w  #$48,d3          ; Set Y position (72 pixels) for wordmark
            moveq   #0,d4            ; Clear Y offset for wordmark
            moveq   #$12,d5          ; Set sprite count for E letter wordmark
            bsr.w   SetupWordmarkSprites ; Call subroutine to set up E wordmark sprites
            lea     (CLetterWordmarkData).l,a0 ; Load sprite data for C letter wordmark
            lea     (CLetterSpriteData).l,a1 ; Load additional sprite data for C letter
            move.w  #$88,d2          ; Set X position offset (136 pixels) for wordmark
            move.w  #$48,d3          ; Set Y position (72 pixels) for wordmark
            move.w  #$48,d4          ; Set Y offset (72 pixels) for wordmark
            moveq   #$24,d5          ; Set sprite count for C letter wordmark
            bsr.w   SetupWordmarkSprites ; Call subroutine to set up C wordmark sprites
            lea     (ALetterWordmarkData).l,a0 ; Load sprite data for A letter wordmark
            lea     (ALetterSpriteData).l,a1 ; Load additional sprite data for A letter
            move.w  #$B0,d2          ; Set X position offset (176 pixels) for wordmark
            move.w  #$46,d3          ; Set Y position (70 pixels) for wordmark
            move.w  #$90,d4          ; Set Y offset (144 pixels) for wordmark
            moveq   #0,d5            ; Set sprite count for A letter wordmark
            bsr.w   SetupWordmarkSprites ; Call subroutine to set up A wordmark sprites
            lea     (LogoPaletteBuffer).l,a1 ; Load palette data for color transitions
            lea     LogoAnimationTable(pc),a3 ; Load animation data table
            moveq   #0,d2            ; Clear tile index for palette processing
            move.b  1(a3),d2         ; Read high byte of tile index
            asl.w   #8,d2            ; Shift to form word
            move.b  (a3),d2          ; Read low byte of tile index
            addq.w  #4,a3            ; Advance to next animation data entry
            bsr.w   ProcessLogoPalette ; Call subroutine to process palette data
            lea     (LogoPaletteBuffer).l,a1 ; Reload palette data
            move.w  (a1)+,d0         ; Read width of palette data
            move.w  (a1)+,d1         ; Read height of palette data
            move.w  (a1)+,d2         ; Read tile count for palette
            moveq   #$F,d3           ; Set loop counter for 16 colors
            move.l  #$C0000000,(VDP_CTRL).l ; Set VDP to CRAM for palette updates
WritePaletteColors:                     ; CODE XREF: EALogoGraphicsInit+1E2↓j
            move.w  (a1)+,(a5)       ; Write palette color to VDP
            dbf     d3,WritePaletteColors ; Loop for 16 colors
            asl.w   #3,d0            ; Scale width (multiply by 8 for tile size)
            subq.w  #1,d0            ; Adjust width for loop
            move.l  #$40200000,(VDP_CTRL).l ; Set VDP to VRAM for tile data
WriteTileData:                         ; CODE XREF: EALogoGraphicsInit+1F6↓j
            move.l  (a1)+,(a5)       ; Write tile data to VDP
            dbf     d0,WriteTileData ; Loop for width
            move.l  #$40000002,(VDP_CTRL).l ; Set VDP to VRAM for sprite table
            move.w  #$720C,d6        ; Set base VDP address for sprite data
            subq.w  #1,d1            ; Adjust height for loop
            subq.w  #1,d2            ; Adjust tile count for loop
            move.w  d2,d0            ; Copy tile count to d0
            move.w  #$8001,d4        ; Set base tile index for sprites
WriteSpriteTiles:                      ; CODE XREF: EALogoGraphicsInit+222↓j
            move.w  d6,(a4)          ; Write VDP address to control port
            addi.w  #$100,d6         ; Increment VDP address
            move.w  d2,d0            ; Copy tile count
WriteSpriteTileRow:                    ; CODE XREF: EALogoGraphicsInit+21E↓j
            move.w  d4,(a5)          ; Write tile index to VDP
            addq.w  #1,d4            ; Increment tile index
            dbf     d0,WriteSpriteTileRow ; Loop for tile count
            dbf     d1,WriteSpriteTiles ; Loop for height
            move.w  #$7044,(a4)      ; Set VDP address for palette entry
            bsr.s   UpdatePaletteEntries ; Update palette entries
            move.w  #$7144,(a4)      ; Set VDP address for next palette entry
            bsr.s   UpdatePaletteEntries ; Update palette entries
            move.w  #$710C,(a4)      ; Set VDP address for next palette entry
            bsr.s   UpdatePaletteEntries ; Update palette entries
            move.w  #$7136,(a4)      ; Set VDP address for final palette entry
            move.w  d4,(a5)          ; Write final tile index to VDP
            move.w  #$96,(AnimationFrameCounter).l ; Set frame counter for animation timing
            rts                      ; Return
; End of function EALogoGraphicsInit

; ===========================================================================
; UpdatePaletteEntries: Updates palette entries for logo color changes
; Writes palette entries to the VDP to handle color transitions (green, yellow,
; blue) for the ECA letters and wordmark during the animation.
; ===========================================================================
UpdatePaletteEntries:                   ; CODE XREF: EALogoGraphicsInit+22A↑p
                                    ; EALogoGraphicsInit+230↑p ...
            move.w  d4,(a5)          ; Write palette entry to VDP
            addq.w  #1,d4            ; Increment palette index
            move.w  d4,(a5)          ; Write next palette entry
            addq.w  #1,d4            ; Increment palette index
            rts                      ; Return
; End of function UpdatePaletteEntries

; ===========================================================================
; ProcessLogoPalette: Processes palette data for logo animation
; Handles palette data for the ECA letters and wordmark, managing color
; transitions (e.g., green to yellow to blue) using run-length encoding (RLE).
; ===========================================================================
ProcessLogoPalette:                    ; CODE XREF: EALogoGraphicsInit+1C4↑p
            movem.l d0-d7/a0-a6,-(sp) ; Save registers
            lea     (TempPaletteBuffer).l,a2 ; Load temporary palette buffer
            movea.l a2,a0            ; Copy buffer address
            move.l  #$20202020,d3    ; Set default palette fill value
            move.w  #$3FF,d0         ; Set loop counter (1023 longs)
ClearPaletteBuffer:                    ; CODE XREF: ProcessLogoPalette+1A↓j
            move.l  d3,(a0)          ; Fill buffer with default value
            addq.l  #4,a0            ; Advance buffer pointer
            dbf     d0,ClearPaletteBuffer ; Loop for 1023 longs
            move.w  #$FEE,d7         ; Set initial buffer index
            move.w  #0,d3            ; Clear bit counter
            moveq   #0,d6            ; Clear control byte counter
ProcessPaletteBits:                    ; CODE XREF: ProcessLogoPalette+4E↓j
                                    ; ProcessPaletteBits+86↓j
            dbf     d3,ReadPaletteByte ; Loop if bit counter > 0
            move.b  (a3)+,d0         ; Read control byte from animation table
            move.b  d0,d6            ; Copy control byte for bit testing
            move.w  #7,d3            ; Set bit counter (8 bits)
ReadPaletteByte:                       ; CODE XREF: ProcessLogoPalette:ProcessPaletteBits↑j
            move.b  (a3)+,d0         ; Read data byte from animation table
            lsr.b   #1,d6            ; Shift control byte to test next bit
            bcc.w   HandleRLEData     ; Branch if bit is clear (RLE data)
            move.b  d0,(a1)+         ; Write data byte to palette buffer
            subq.l  #1,d2            ; Decrement tile count
            beq.w   ExitPaletteProcessing ; Exit if no more tiles
            move.b  d0,(a2,d7.w)     ; Write data byte to temporary buffer
            addq.w  #1,d7            ; Increment buffer index
            andi.w  #$FFF,d7         ; Wrap index at 4096
            bra.s   ProcessPaletteBits ; Continue processing bits
HandleRLEData:                         ; CODE XREF: ProcessLogoPalette+38↑j
            moveq   #0,d4            ; Clear run length counter
            move.b  d0,d4            ; Copy data byte to run length
            move.b  (a3)+,d0         ; Read next byte (run count)
            move.b  d0,d5            ; Copy to run counter
            andi.w  #$F0,d0          ; Mask high nibble for index
            asl.w   #4,d0            ; Shift to form index
            or.w    d0,d4            ; Combine with data byte
            andi.w  #$F,d5           ; Mask low nibble for run count
            addq.w  #2,d5            ; Adjust run length (add 2)
CopyRLEData:                           ; CODE XREF: ProcessLogoPalette+82↓j
            move.b  (a2,d4.w),d0     ; Read byte from temporary buffer
            addq.w  #1,d4            ; Increment buffer index
            andi.w  #$FFF,d4         ; Wrap index at 4096
            move.b  d0,(a1)+         ; Write byte to palette buffer
            subq.l  #1,d2            ; Decrement tile count
            beq.w   ExitPaletteProcessing ; Exit if no more tiles
            move.b  d0,(a2,d7.w)     ; Write byte to temporary buffer
            addq.w  #1,d7            ; Increment buffer index
            andi.w  #$FFF,d7         ; Wrap index at 4096
            dbf     d5,CopyRLEData   ; Loop for run length
            bra.s   ProcessPaletteBits ; Continue processing bits
ExitPaletteProcessing:                 ; CODE XREF: ProcessLogoPalette+40↑j
                                    ; ProcessLogoPalette+74↑j
            movem.l (sp)+,d0-d7/a0-a6 ; Restore registers
            rts                      ; Return
; End of function ProcessLogoPalette

WordmarkAnimationTable ;unk_FFC012 D58
	incbin ..\Extracted\Graphics\EALogo.WordmarkAnimationTable.bin
WordmarkPositionTable ; = $D61
    incbin ..\Extracted\Graphics\EALogo.WordmarkPositionTable.bin
WordmarkOffsetTable ;= $D7C
    incbin ..\Extracted\Graphics\EALogo.WordmarkOffsetTable.bin
WordmarkFadeTable ;= $D85
    incbin ..\Extracted\Graphics\EALogo.WordmarkFadeTable.bin
LogoAnimationTable ; unk_D8E
	incbin ..\Extracted\Graphics\EALogo.LogoAnimationTable.bin
NextProgramSection