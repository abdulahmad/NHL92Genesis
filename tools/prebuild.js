// prebuild.js: run first by every build (tools/build.js).
// Usage: node tools/prebuild.js [retail|reva|dev]
// The ROM must be present (and the right version); then makes sure Extracted/ is complete, and runs
// the extractor if it is not. If the ROM is missing or wrong, stops with the path, file name, SHA-1
// and size it must have.
// Adapted from NHL94Genesis tools/prebuild.js.

const GAME = 'NHL Hockey (NHL 92, Sega Genesis)';
const EXTRACTOR = 'tools/extractAssets92.js';
const { ROMS, findRom, sha1Of } = require('./roms');
// The ROM each target needs: retail and reva are verified against their own ROM; dev needs either one.
// The assets are extracted from that ROM (retail and Rev A give identical assets).
const TARGETS = { retail: ['retail'], reva: ['reva'], dev: ['retail', 'reva'] };
// ---------------------------------------------------------------------------------------------
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const EXTRACTED = path.join(ROOT, 'Extracted');
const MARKER = path.join(EXTRACTED, '.extract-complete.json');

const sizeText = (n) => `${n} bytes (0x${n.toString(16).toUpperCase()}, ${n / 0x100000 >= 1 ? n / 0x100000 + ' MB' : n / 1024 + ' KB'})`;

// Check one ROM: a file in the repo folder with this SHA-1 and size, whatever its name (tools/roms.js).
const checkRom = findRom;

// The ROM message: colors when the build asked for them (NHL_COLOR) or on a terminal; emoji on a UTF-8 terminal (NHL_EMOJI=0/1 overrides).
const COLOR = Boolean(process.env.NHL_COLOR) || (Boolean(process.stderr.isTTY) && !('NO_COLOR' in process.env));
const EMOJI = process.env.NHL_EMOJI !== undefined ? process.env.NHL_EMOJI === '1'
    : process.platform === 'win32' ? Boolean(process.env.WT_SESSION || process.env.TERM_PROGRAM || process.env.ConEmuANSI)
    : /utf-?8/i.test(process.env.LC_ALL || process.env.LC_CTYPE || process.env.LANG || '');
const sgr = (code) => (t) => (COLOR ? `\x1b[${code}m${t}\x1b[0m` : String(t));
const k = { red: sgr('1;31'), green: sgr('32'), yellow: sgr('33'), cyan: sgr('36'), bold: sgr('1'), dim: sgr('2') };
const icon = (emoji, plain) => (EMOJI ? `${emoji} ` : plain ? `${plain} ` : '');

function romBlock(rom) {
    return [
        `    ${k.bold(rom.label)}`,
        `      ${k.cyan('Put it in:')}  ${ROOT}`,
        `      ${k.cyan('Any name:')}   it is found by its SHA-1 and size (${rom.file} is the usual name)`,
        `      ${k.cyan('SHA-1:')}      ${k.yellow(rom.sha1)}`,
        `      ${k.cyan('Size:')}       ${sizeText(rom.size)}`,
    ].join('\n');
}

// info: { building: what the build needs, wrong: [{ path, sha1, size }] files that are not the right ROM, hint: what a wrong file may be,
//         have: [{ label, id }] other revisions whose ROM is in the folder, want: [rom] the ROMs that would let this build run }
function stop(info) {
    const out = ['', k.red(`${icon('\u{1F6D1}', 'X')}BUILD STOPPED: ROM needed`)];
    out.push(`${icon('\u{1F3D2}', '')}You are building ${k.cyan(info.building)}, but ${info.wrong.length ? 'the ROM in the repo folder is not that one' : 'no ROM of ' + (info.want.length > 1 ? 'those revisions' : 'that revision') + ' is in the repo folder'}.`);
    for (const w of info.wrong) {
        out.push('', k.yellow(`${icon('\u26A0\uFE0F', '!')}Found ${w.path}, but it is not the right ROM:`));
        out.push(`    its SHA-1 is ${k.yellow(w.sha1)}, size ${sizeText(w.size)}.`);
        out.push(k.dim(`    (${info.hint})`));
    }
    if (info.have && info.have.length) {
        out.push('', k.green(`${icon('\u2705', 'OK')}The ROMs you have, and the command that builds each:`));
        for (const h of info.have) out.push(`    ${k.green('\u2713')} ${h.label}  ${k.dim('->')}  ${k.bold(`npm run build:${h.id}`)}`);
    }
    out.push('', k.cyan(`${icon('\u{1F4C0}', '')}${info.have && info.have.length ? 'To build the one you asked for, add this ROM' : info.want.length > 1 ? 'This build needs one of these ROMs, each exactly the version shown' : 'This build needs this ROM, exactly the version shown'}:`));
    for (const rom of info.want) out.push(romBlock(rom));
    out.push('', k.dim(`${icon('\u2139\uFE0F', '')}ROMs are not included in the repo. Use your own dump of the ${GAME} cartridge, in the repo folder under any file name${info.noheader ? ' (no copier header)' : ''}, then run the build again. The assets in Extracted/ are then extracted from it automatically.`), '');
    console.error(out.join('\n'));
    process.exit(1);
}

// Is Extracted/ complete? The extractor writes the marker last, listing every file it wrote, the
// ROM it read and its own SHA-1. Any missing or resized file, an unknown ROM or a changed extractor
// means the folder has to be extracted again.
function extractedState() {
    if (!fs.existsSync(EXTRACTED)) return 'Extracted/ is missing';
    if (!fs.existsSync(MARKER)) return 'Extracted/ is incomplete (no .extract-complete.json marker)';
    let m;
    try { m = JSON.parse(fs.readFileSync(MARKER, 'utf8')); } catch (e) { return 'the Extracted/ marker is unreadable'; }
    if (m.extractorSha1 !== sha1Of(fs.readFileSync(path.join(ROOT, EXTRACTOR)))) return `${EXTRACTOR} changed since the last extraction`;
    if (!Object.values(ROMS).some((r) => r.sha1 === m.romSha1)) return 'Extracted/ came from an unknown ROM';
    if (!Array.isArray(m.files) || m.files.length === 0) return 'the Extracted/ marker lists no files';
    for (const f of m.files) {
        const p = path.join(EXTRACTED, f.path);
        if (!fs.existsSync(p)) return `Extracted/${f.path} is missing`;
        if (fs.statSync(p).size !== f.size) return `Extracted/${f.path} has the wrong size`;
    }
    return null;
}

const target = process.argv[2] || 'retail';
if (!TARGETS[target]) {
    console.error(`prebuild: unknown target '${target}'. Use one of: ${Object.keys(TARGETS).join(', ')}`);
    process.exit(1);
}

// 1. The ROM this build needs (for dev, the first known ROM present).
const candidates = TARGETS[target].map((id) => ROMS[id]);
const problems = [];
let romPath = null;
for (const rom of candidates) {
    const r = checkRom(rom);
    if (r.ok) { romPath = r.path; break; }
    problems.push({ rom, r });
}
if (!romPath) {
    const wrong = problems.filter((x) => x.r.reason === 'wrong').map((x) => x.r);
    const have = Object.keys(ROMS).length > 1 ? Object.keys(ROMS).filter((id) => findRom(ROMS[id]).ok).map((id) => ({ id, label: ROMS[id].label })) : [];
    stop({ building: candidates.map((r) => r.label).join(' or '), wrong, have, want: candidates,
           hint: 'a bad dump, a hack, another revision, or a byte-swapped / interleaved file' });
}

// 2. Extracted/ assets: extract again if missing or incomplete.
const why = extractedState();
if (!why) {
    console.log('prebuild: ROM OK, Extracted/ assets complete.');
    process.exit(0);
}
console.log(`prebuild: ${why}; extracting assets from ${path.relative(ROOT, romPath)} ...`);
const res = spawnSync(process.execPath, [path.join(ROOT, EXTRACTOR), romPath], { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const out = (res.stdout || '') + (res.stderr || '');
const after = res.status === 0 ? extractedState() : 'the extractor failed';
if (after) {
    console.error(out);
    console.error(`*** BUILD STOPPED: asset extraction failed (${after}) ***`);
    process.exit(1);
}
const summary = out.split(/\r?\n/).filter((l) => /^ROM:|^Extracted \d+ (assets|slices)/.test(l));
for (const l of summary) console.log('prebuild: ' + l);
console.log('prebuild: Extracted/ assets complete.');
