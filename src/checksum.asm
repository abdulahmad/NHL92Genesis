; NHL Hockey (Sega Genesis, Retail Version)
; Extra code at ROM offset 0x7FE8A
; Likely a security/validation routine followed by VDP initialization or error state
; Absent in dev version, suggesting anti-piracy or retail-specific functionality

SecurityCheck:
            DC.W    $FFFF        ; Padding, marker, or data (not a valid instruction)

ValidationRoutine:
            MOVEQ   #0, D0       ; Clear D0 (initialize checksum or accumulator)
            SUBA.L   A0, A0       ; Normalize A0 (subtract D0 from address register)
            MOVE.L  #$1FFA3, D1  ; Load address $1FFA3 into A1 (data pointer?)
ValidationLoop:
            CMPA.W  #$18C, A0    ; Check if A0 equals $18C (memory boundary)
            BNE.S   SkipIncrement ; Branch if not equal
            ADDQ.W  #4, A0       ; Increment A0 by 4 (skip bytes or align)
            BRA.S   ContinueValidation ; Proceed to next step
SkipIncrement:
            ADD.L   (A0)+, D0     ; Accumulate value at A0 into D0
ContinueValidation:
            SUBQ.L  #1, D1     ; Decrement counter at A1
            BGT.S   ValidationLoop ; Loop if counter > 0
            IF REV=0 ; RETAIL
                CMPI.L  #$9BB2FE9B, D0 ; Compare D0 with $9BB2FE9B (expected checksum)
            ELSE ; REV A
                CMPI.L  #$98580724, D0 ; Compare D0 with $98580724 (expected checksum)
            ENDIF
            BNE.S   VDPErrorSetup ; Branch to VDP setup if checksum fails
            RTS                  ; Return if validation passes

VDPErrorSetup:
            ; Likely an error state (e.g., failed checksum) or final VDP init
            MOVEA.L #Vctrl, A4 ; Load VDP control port ($C00004)
            MOVE.W  #$8F02, (A4)  ; Set VDP auto-increment to 2
            MOVE.W  #$8004, (A4)  ; Set VDP mode (disable H-blank, set mode)
            MOVE.W  #$8700, (A4)  ; Set background color (palette 0, entry 0)
            MOVE.W  #$8144, (A4)  ; Enable display, V-blank, DMA
            MOVE.W  #$C000, (A4)  ; Set VRAM write address to $0000
            MOVE.W  #$3F, D1     ; Set counter for 64 iterations

VRAMWriteLoop:
            MOVE.W  #$0E, Vdata  ; Write $0E to VDP data port ($C00000)
            DBF     D1, VRAMWriteLoop ; Loop until D1 = -1

Halt:
            BRA.S   Halt         ; Infinite loop (halts execution, e.g., error state)