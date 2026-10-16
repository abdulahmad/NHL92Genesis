#!/bin/bash
# verify_all.sh: fresh asset extraction, then the retail and Rev A builds with tools/build.js (wine on
# Linux/macOS), each verified against its ROM. Usage: tools/verify_all.sh
cd "$(dirname "$0")/.." || exit 1
fail=0
rm -rf Extracted output
for m in retail reva; do
  r=$(node tools/build.js $m) ; echo "$r" | grep -E 'verify|FAILED'
  echo "$r" | grep -qE 'verify +MATCH' || { echo "$r"; fail=1; }
done
[ "$fail" = 1 ] && { echo "VERIFY FAILED"; exit 1; }
echo "ALL MATCH"
