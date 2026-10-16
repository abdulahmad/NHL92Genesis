@echo off
setlocal

REM Get the directory of this batch file
set "workspaceFolder=%~dp0"

REM Set default values for rev and checksum if not provided
if not defined rev set rev=0
if not defined checksum set checksum=1

REM Pre-step: tools\prebuild.js checks the ROM(s) and Extracted/ and extracts the assets if they are missing
REM or incomplete; it stops the build with the ROM path, SHA-1 and size if a ROM is missing. The npm
REM scripts run it first and set NHL_PREBUILD_DONE; tools/verify_all.sh does the same under wine.
set "prebuildTarget=retail"
if "%rev%"=="1" set "prebuildTarget=reva"
if "%checksum%"=="0" set "prebuildTarget=dev"
if not defined NHL_PREBUILD_DONE (
    node "%workspaceFolder%tools\prebuild.js" %prebuildTarget% || exit /b 1
)

REM The main ROM includes output\modified_EALogo.bin and output\modified_Hockey.snd: build them first.
REM tools/verify_all.sh builds them itself (no node under wine) and sets NHL_SUBBUILDS_DONE.
if not defined NHL_SUBBUILDS_DONE (
    call "%workspaceFolder%buildEALogo.bat" || exit /b 1
    node "%workspaceFolder%tools\fixopcodes.js" "%workspaceFolder%output\EALogo .lst" "%workspaceFolder%output\EALogo.bin" > "%workspaceFolder%output\fixopcodes_EALogo.log" || exit /b 1
    call "%workspaceFolder%buildSound.bat" || exit /b 1
    node "%workspaceFolder%tools\fixopcodes.js" "%workspaceFolder%output\Hockey .lst" "%workspaceFolder%output\Hockey.snd" > "%workspaceFolder%output\fixopcodes_Hockey.log" || exit /b 1
)

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
  "%workspaceFolder%src\hockey.asm,%workspaceFolder%output\nhl92.bin,%workspaceFolder%output\nhl92,%workspaceFolder%output\nhl92" ^
  > "%workspaceFolder%output\Build.log"

endlocal
