// Compare a built ROM to a reference ROM. Exit 1 unless every byte matches.
// Usage: node tools/verifyRom.js <built.bin> <reference.bin | retail | reva> [maxMismatches]   (an id: the ROM in the repo folder, tools/roms.js)
const fs = require('fs');
const { romPath } = require('./roms');

const [builtPath, referenceArg, maxArg] = process.argv.slice(2);
const referencePath = referenceArg && !fs.existsSync(referenceArg) ? (romPath(referenceArg) || referenceArg) : referenceArg;
const maxMismatches = Number(maxArg || 16);

if (!builtPath || !referencePath) {
  console.error('Usage: node tools/verifyRom.js <built.bin> <reference.bin> [maxMismatches]');
  process.exit(1);
}

const built = fs.readFileSync(builtPath);
const reference = fs.readFileSync(referencePath);

if (built.length !== reference.length) {
  console.error(
    `LENGTH MISMATCH: ${builtPath} is ${built.length} bytes, ${referencePath} is ${reference.length} bytes`
  );
  process.exit(1);
}

const mismatches = [];
for (let i = 0; i < built.length; i++) {
  if (built[i] !== reference[i]) {
    mismatches.push(i);
    if (mismatches.length >= maxMismatches) break;
  }
}

if (mismatches.length === 0) {
  console.log(`MATCH: ${builtPath} == ${referencePath} (${built.length} bytes)`);
  process.exit(0);
}

let total = 0;
for (let i = 0; i < built.length; i++) {
  if (built[i] !== reference[i]) total++;
}

console.error(`MISMATCH: ${total} bytes differ. First ${mismatches.length}:`);
for (const offset of mismatches) {
  const got = built[offset].toString(16).padStart(2, '0');
  const want = reference[offset].toString(16).padStart(2, '0');
  console.error(`  0x${offset.toString(16).padStart(6, '0')}: built ${got} reference ${want}`);
}
process.exit(1);
