#!/bin/bash
# verify_all.sh: fresh asset extraction, then the retail and Rev A builds with tools/build.js (wine on
# Linux/macOS), each verified against its ROM. Usage: tools/verify_all.sh
export WINEDEBUG=-all
cd "$(dirname "$0")/.." || exit 1
fail=0
rm -rf Extracted output
for m in retail reva; do
  # build.js prints the result of each step on an indented line under it: "   MATCH output/retail/nhl92.bin == ...".
  r=$(node tools/build.js $m)
  last=$(echo "$r" | grep -E '^ +MATCH ')
  case "$last" in
    *MATCH*) echo "$m: ${last#"${last%%[! ]*}"}" ;;
    *) echo "$m: FAILED"; echo "$r"; fail=1 ;;
  esac
done
if [ "$fail" = 1 ]; then
  echo "VERIFY FAILED"
  exit 1
fi
echo "ALL MATCH"
exit 0
