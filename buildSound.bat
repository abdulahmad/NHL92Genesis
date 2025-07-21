@echo off
setlocal

REM Get the directory of this batch file
set "workspaceFolder=%~dp0"

REM Set default values for rev and checksum if not provided
if not defined rev set rev=0
if not defined checksum set checksum=1

@REM echo Using rev=%rev% and checksum=%checksum%

REM Create the output directory
if not exist "%workspaceFolder%output" mkdir "%workspaceFolder%output"

REM Change to the workspace src directory
cd /d "%workspaceFolder%src"

REM Determine revision flag
if "%REV%"=="1" (
    set revFlag="/e REV=1"
    ECHO "its reva"
) else (
    set revFlag="/e REV=0"
    ECHO "its retail"
)

REM Determine checksum flag
if "%checksum%"=="0" (
    set checksumFlag="/e CHECKSUM=0"
) else (
    set checksumFlag="/e CHECKSUM=1"
)

REM Run the assembler with all flags
"%workspaceFolder%assembler\Assembler.exe" ^
  /p /m /g ^
  /o d- /o s- /o r+ /o l+ /o l. /o ow+ /o op- /o os+ /o oz+ /o omq- /o oaq+ /o osq+ ^
  %revFlag% %checksumFlag% ^
  "%workspaceFolder%src\sound\sound.asm,%workspaceFolder%output\Hockey.snd,%workspaceFolder%output\Hockey,%workspaceFolder%output\Hockey" ^
  > "%workspaceFolder%output\Build.log"

endlocal
