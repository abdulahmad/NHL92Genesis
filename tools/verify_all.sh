#!/bin/bash
# verify_all.sh: build retail and Rev A under wine and compare each to its reference ROM.
# Usage: tools/verify_all.sh   (needs wine, node, nhl92retail.bin and nhl92retailRevA.bin in the repo folder)
# tools/prebuild.js runs here with Linux node (fresh extract, ROM check); the .bat files skip it and the
# logo / sound sub-builds (no node under wine), so this script builds those itself.
cd "$(dirname "$0")/.." || exit 1
export WINEDEBUG=-all NHL_PREBUILD_DONE=1 NHL_SUBBUILDS_DONE=1
rm -rf Extracted output
node tools/prebuild.js reva >/tmp/x92.log 2>&1 || { echo "PREBUILD FAIL"; cat /tmp/x92.log; exit 1; }
mkdir -p output
fail=0
for t in "retail 0 nhl92retail.bin" "reva 1 nhl92retailRevA.bin"; do
  set -- $t; name=$1; rev=$2; ref=$3
  rm -f output/*.bin output/*.snd
  wine cmd /c "set rev=$rev&& set checksum=1&& buildEALogo.bat" >/dev/null 2>&1
  node tools/fixopcodes.js "output/EALogo .lst" output/EALogo.bin >/dev/null 2>&1 || { echo "$name: LOGO FAIL"; fail=1; continue; }
  wine cmd /c "set rev=$rev&& set checksum=1&& buildSound.bat" >/dev/null 2>&1
  node tools/fixopcodes.js "output/Hockey .lst" output/Hockey.snd >/dev/null 2>&1 || { echo "$name: SOUND FAIL"; fail=1; continue; }
  wine cmd /c "set rev=$rev&& set checksum=1&& build.bat" >/dev/null 2>&1
  grep -qP '^[1-9]\d* error' output/Build.log && echo "$name: ASM ERRORS in output/Build.log"
  node tools/fixopcodes.js "output/nhl92 .lst" output/nhl92.bin >/dev/null 2>&1 || { echo "$name: NO BIN"; fail=1; continue; }
  r=$(node tools/verifyRom.js output/modified_nhl92.bin "$ref" 2>&1 | head -3); echo "$name: $r"
  echo "$r" | grep -q '^MATCH' || fail=1
done
exit $fail
