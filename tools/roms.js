// roms.js: the ROMs this build needs, and where they are. A ROM is found in the repo's root folder by its content (size, then
// SHA-1), so the file can have any name; the usual name (`file` below) is tried first. Used by tools/prebuild.js, tools/build.js,
// tools/verifyRom.js and the extractor, and from the command line (prints the path of a ROM):
//   node tools/roms.js [retail|reva]
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.join(__dirname, '..');
const ROMS = {
    retail: { label: 'NHL Hockey (NHL 92) retail (1991.MAY, GM T-50236 -00)', file: 'nhl92retail.bin',
              sha1: '2337ad3c065f46edccf19007d7a5be80a97520d5', size: 0x80000 },
    reva:   { label: 'NHL Hockey (NHL 92) Rev A', file: 'nhl92retailRevA.bin',
              sha1: '10b50ebf3db0b4d207e21acf4481eb704b3c45f9', size: 0x80000 },
};
// The file extensions of ROM dumps that are looked at (Mega Drive dumps are .bin, .gen or .md).
const ROM_FILE = /\.(bin|gen|md)$/i;

const sha1Of = (buf) => crypto.createHash('sha1').update(buf).digest('hex');
const hashes = new Map();                                             // file path -> { sha1, size }: the revisions share a size

function hashOf(p) {
    if (!hashes.has(p)) { const data = fs.readFileSync(p); hashes.set(p, { sha1: sha1Of(data), size: data.length }); }
    return hashes.get(p);
}

// { ok: true, path } when a file in the root folder is this ROM; otherwise { ok: false, reason: 'missing' } or, when the file
// with the usual name is there but is not this ROM, { ok: false, reason: 'wrong', path, sha1, size }.
function findRom(rom) {
    const names = [rom.file, ...fs.readdirSync(ROOT).filter((f) => f !== rom.file && ROM_FILE.test(f))];
    let wrong = null;
    for (const name of names) {
        const p = path.join(ROOT, name);
        let st;
        try { st = fs.statSync(p); } catch (e) { continue; }
        if (!st.isFile()) continue;
        if (st.size !== rom.size && name !== rom.file) continue;      // not worth reading
        const h = hashOf(p);
        if (h.sha1 === rom.sha1 && h.size === rom.size) return { ok: true, path: p };
        if (name === rom.file) wrong = { ok: false, reason: 'wrong', path: p, sha1: h.sha1, size: h.size };
    }
    return wrong || { ok: false, reason: 'missing', path: path.join(ROOT, rom.file) };
}

// The path of the ROM with this id ('retail', 'reva'), or null.
function romPath(id = 'retail') {
    const rom = ROMS[id];
    const r = rom && findRom(rom);
    return r && r.ok ? r.path : null;
}

module.exports = { ROOT, ROMS, findRom, romPath, sha1Of };

if (require.main === module) {
    const id = process.argv[2] || 'retail';
    const p = romPath(id);
    if (!p) { console.error(`The ${id} ROM is not in the repo folder (see node tools/prebuild.js ${id}).`); process.exit(1); }
    console.log(p);
}
