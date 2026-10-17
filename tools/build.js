#!/usr/bin/env node
// build.js: the whole NHL 92 build, one line per step, on Windows and on Linux/macOS (wine).
// Replaces build.bat / buildEALogo.bat / buildSound.bat (as in NHL94Genesis tools/build.js).
//   node tools/build.js [retail|reva|dev] [--verbose]   full ROM -> output/<mode>/nhl92.bin
//   node tools/build.js [mode] --logo | --sound         only the EA logo (output/<mode>/obj/modified_EALogo.bin) or the
//                                                       sound driver (output/<mode>/obj/modified_Hockey.snd)
//   node tools/build.js --clean                         delete output/ and Extracted/
// --no-color (or NO_COLOR) turns the colors off; they are also off when the output is not a terminal.
// retail: REV=0 CHECKSUM=1, verified against nhl92retail.bin. reva: REV=1 CHECKSUM=1, verified against
// nhl92retailRevA.bin. dev: REV=1 CHECKSUM=0 (no validation routine), not verified.
// Each mode has its own folder: output/<mode>/nhl92.bin is the ROM, output/<mode>/obj/ holds the intermediates (the
// modified logo and sound binaries, assembler logs and listings). The main ROM includes the modified logo and sound
// binaries, which are built first and copied to output/modified_EALogo.bin and output/modified_Hockey.snd, the paths
// src/main.asm and src/hockey.asm include them from (the sources are EA's, unchanged).
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const ROOT = path.join(__dirname, '..');
const WIN = process.platform === 'win32';
const EXE = path.join(ROOT, 'assembler', 'Assembler.exe');
const MODES = {
    retail: { rev: 0, checksum: 1, prebuild: 'retail', ref: 'nhl92retail.bin' },
    reva: { rev: 1, checksum: 1, prebuild: 'reva', ref: 'nhl92retailRevA.bin' },
    dev: { rev: 1, checksum: 0, prebuild: 'dev', ref: null },
};

const args = process.argv.slice(2);
const verbose = args.includes('--verbose');
const modeName = args.find((a) => MODES[a]) || 'retail';
const mode = MODES[modeName];
const OUT = path.join(ROOT, 'output', modeName);
const OBJ = path.join(OUT, 'obj');
const ROM = 'nhl92.bin';
const only = args.includes('--logo') ? 'logo' : args.includes('--sound') ? 'sound' : null;
const rel = (p) => path.relative(ROOT, p).split(path.sep).join('/');

// ANSI colors: off when stdout is not a terminal, NO_COLOR is set, or --no-color. Windows 10+ cmd and
// PowerShell take ANSI codes from Node directly.
const color = process.stdout.isTTY && !('NO_COLOR' in process.env) && !args.includes('--no-color');
const sgr = (code) => (t) => (color ? `\x1b[${code}m${t}\x1b[0m` : String(t));
const c = { dim: sgr('2'), cyan: sgr('36'), green: sgr('32'), yellow: sgr('33'), red: sgr('31'), bold: sgr('1') };
// Values (numbers, $hex, output paths) bold; OK / MATCH green; warnings yellow.
const paint = (t) => t
    .replace(/(output\/\S+|\$[0-9A-F]+|\b\d+(?:\.\d+)?s?\b)/g, (m) => c.bold(m))
    .replace(/\b(MATCH|OK)\b/g, (m) => c.green(m))
    .replace(/\b([1-9]\d*)(\x1b\[0m)? (warnings|skipped)/g, (m) => c.yellow(m))
    .replace(/not verified \([^)]*\)/, (m) => c.yellow(m));

let steps = 0;
let n = 0;
// Each step is two lines: "[n/6] <step>  <description>", then the result under the description.
// In a colour terminal the step line shows a spinner and a yellow step name while it runs, and is
// redrawn with a green check or a red cross when it ends (cut to the terminal width so it never
// wraps). Otherwise both lines are printed once, after the step.
const ROMNAME = { retail: 'retail', reva: 'Rev A', dev: 'retail or Rev A' }[modeName];
const ABOUT = {
    prebuild: `check the ${only ? 'retail or Rev A' : ROMNAME} ROM and extract graphics/sound assets into Extracted/`,
    logo: 'SNASM68k builds the EA logo intro, then its opcodes are patched',
    sound: 'SNASM68k builds the sound driver and music, then its opcodes are patched',
    assemble: 'SNASM68k turns src/hockey.asm (with the logo and sound) into a raw ROM image',
    fixopcodes: "patch the instructions where SNASM picks a different encoding than EA's original assembler",
    verify: modeName === 'dev' ? 'compare byte-for-byte with a retail ROM (only retail and reva builds)' : `compare byte-for-byte with the ${ROMNAME} ROM`,
    output: 'delete the built ROMs and intermediates in output/',
    Extracted: 'delete extracted graphics/sound assets (rebuilt by the next build)',
};
const live = color;
// Braille spinner and check marks need a UTF-8 terminal; old Windows consoles get ASCII.
const utf8 = WIN ? Boolean(process.env.WT_SESSION || process.env.TERM_PROGRAM || process.env.ConEmuANSI)
    : /utf-?8/i.test(process.env.LC_ALL || process.env.LC_CTYPE || process.env.LANG || '');
const SPIN = utf8 ? ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'] : ['|', '/', '-', '\\'];
const OK = utf8 ? '✓' : 'OK';
const BAD = utf8 ? '✗' : 'X';
const MARK = Math.max(OK.length, BAD.length, 1);
const INDENT = ' '.repeat(`[0/0] ${live ? ' '.repeat(MARK + 1) : ''}${''.padEnd(10)} `.length);
let current = null;
let dirty = false;
let timer = null;
let frame = 0;
function header(name, paintName, mark) {
    const head = `[${n}/${steps}] ${live ? `${mark.padEnd(MARK)} ` : ''}${name.padEnd(10)} `;
    let desc = ABOUT[name] || '';
    const width = live ? (process.stdout.columns || 80) - 1 : Infinity;
    if (head.length + desc.length > width) desc = desc.slice(0, Math.max(0, width - head.length - 1)) + (width > head.length ? '…'.slice(0, utf8 ? 1 : 0) : '');
    const markPart = live ? `${paintName(mark.padEnd(MARK))} ` : '';
    return `${c.cyan(`[${n}/${steps}]`)} ${markPart}${paintName(name.padEnd(10))} ${c.dim(desc)}`;
}
const draw = (text) => process.stdout.write(`\r\x1b[2K${text}`);
function stopSpin() { if (timer) { clearInterval(timer); timer = null; } }
function begin(name) {
    n++;
    current = name;
    dirty = false;
    if (!live) return;
    frame = 0;
    draw(header(name, c.yellow, SPIN[0]));
    timer = setInterval(() => { frame = (frame + 1) % SPIN.length; draw(header(name, c.yellow, SPIN[frame])); }, 80);
}
function finish(name, paintName, mark) {
    if (current !== name) begin(name);
    stopSpin();
    if (!live) console.log(header(name, (t) => t, ''));
    else if (!dirty) draw(`${header(name, paintName, mark)}\n`);
    else console.log(header(name, paintName, mark));
    current = null;
}
const step = (name, text) => { finish(name, c.green, OK); console.log(INDENT + paint(text)); };
function detail(text) {
    if (!verbose || !text.trim()) return;
    if (live && current && !dirty) { stopSpin(); process.stdout.write('\n'); }
    dirty = true;
    console.log(text.replace(/\s+$/, '').replace(/^/gm, INDENT));
}
function fail(name, text, log, label = 'FAILED') {
    finish(name, c.red, BAD);
    console.log(`${INDENT}${c.red(label)}: ${text}`);
    if (log) console.log(log.replace(/\s+$/, '').replace(/^/gm, INDENT));
    console.log(c.red(`BUILD FAILED at ${name}`));
    process.exit(1);
}
// Child processes run async (spawn) so the spinner keeps turning while the assembler works.
function run(cmd, argv, opts = {}) {
    return new Promise((resolve) => {
        const chunks = [];
        let p;
        try { p = spawn(cmd, argv, { cwd: ROOT, ...opts }); } catch (e) { resolve({ status: -1, out: String(e) }); return; }
        p.stdout.on('data', (d) => chunks.push(d));
        p.stderr.on('data', (d) => chunks.push(d));
        p.on('error', (e) => resolve({ status: -1, out: Buffer.concat(chunks).toString('latin1') + String(e) }));
        p.on('close', (code) => resolve({ status: code, out: Buffer.concat(chunks).toString('latin1') }));
    });
}
const node = (script, argv) => run(process.execPath, [path.join(__dirname, script), ...argv]);

// SNASM68k with the options EA's build matched, directly on Windows, under wine elsewhere.
// src and outputs are relative to src/ (backslashes, as the assembler expects).
async function assemble(name, src, outBase, binExt, rev, checksum) {
    const asmArgs = ['/p', '/m', '/g', '/o', 'd-', '/o', 's-', '/o', 'r+', '/o', 'l+', '/o', 'l.', '/o', 'ow+', '/o', 'op-',
        '/o', 'os+', '/o', 'oz+', '/o', 'omq-', '/o', 'oaq+', '/o', 'osq+',
        '/e', `REV=${rev}`, '/e', `CHECKSUM=${checksum}`, `${src},${outBase}${binExt},${outBase},${outBase}`];
    const r = await (WIN ? run(EXE, asmArgs, { cwd: path.join(ROOT, 'src') })
        : run('wine', [EXE, ...asmArgs], { cwd: path.join(ROOT, 'src'), env: { ...process.env, WINEDEBUG: '-all' } }));
    const base = path.join(ROOT, 'src', outBase.replace(/\\/g, '/'));
    const logPath = path.join(path.dirname(base), `Build_${path.basename(base)}.log`);
    fs.writeFileSync(logPath, r.out, 'latin1');
    const lines = r.out.split(/\r\n|\n|\r/);
    const sum = r.out.match(/(\d+) error\(s\) from (\d+) lines in ([\d.]+) seconds/);
    if (!sum) fail(name, `no assembler summary in ${rel(logPath)} (exit ${r.status})`, lines.slice(-20).join('\n'));
    if (Number(sum[1]) > 0 || !fs.existsSync(base + binExt)) {
        const bad = lines.filter((l) => /\.(asm|inc|mac)\(\d+|error|fatal|not recognised|undefined|could not/i.test(l) && !/error\(s\) from/.test(l)).slice(0, 40);
        fail(name, `${sum[1]} error(s), see ${rel(logPath)}`, bad.join('\n'));
    }
    detail(r.out);
    const warnings = lines.filter((l) => /warning/i.test(l)).length;
    return { bin: base + binExt, lst: `${base} .lst`, errors: Number(sum[1]), warnings, lines: sum[2], secs: sum[3] };
}

// fixopcodes: rewrite the cmp / exg encodings where SNASM picks a different one than EA's assembler.
async function fixopcodes(name, a) {
    const r = await node('fixopcodes.js', [a.lst, a.bin]);
    const m = r.out.match(/Modified (\d+) instructions/);
    const fixed = path.join(path.dirname(a.bin), `modified_${path.basename(a.bin)}`);
    if (r.status !== 0 || !m || !fs.existsSync(fixed)) fail(name, 'fixopcodes did not write the fixed binary', r.out);
    detail(r.out);
    const skipped = (r.out.match(/Skipping/g) || []).length;
    return { fixed, count: m[1], skipped };
}

// The EA logo and the sound driver: assemble + fixopcodes as one step each.
async function subBuild(name, src, base, ext, rev, checksum) {
    begin(name);
    const a = await assemble(name, src, `..\\output\\${modeName}\\obj\\${base}`, ext, rev, checksum);
    const f = await fixopcodes(name, a);
    // EA's sources include these from output/, so the copy of this mode's build goes there.
    fs.copyFileSync(f.fixed, path.join(ROOT, 'output', path.basename(f.fixed)));
    step(name, `${a.errors} errors, ${a.warnings} warnings, ${a.lines} lines in ${a.secs}s, ${f.count} opcodes fixed${f.skipped ? `, ${f.skipped} skipped` : ''} -> ${rel(f.fixed)}`);
}

(async () => {
    if (args.includes('--clean')) {
        steps = 2;
        const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).reduce((a, e) => {
            const f = path.join(d, e.name);
            if (e.isDirectory()) { const r = walk(f); return [a[0] + r[0], a[1] + r[1]]; }
            return [a[0] + 1, a[1] + fs.statSync(f).size];
        }, [0, 0]);
        for (const dir of ['output', 'Extracted']) {
            begin(dir);
            const full = path.join(ROOT, dir);
            if (!fs.existsSync(full)) { step(dir, 'already clean'); continue; }
            const [files, bytes] = walk(full);
            try { fs.rmSync(full, { recursive: true, force: true }); } catch (e) { fail(dir, e.message); }
            step(dir, `removed ${files} files, ${(bytes / 1048576).toFixed(1)} MB`);
        }
        console.log(c.green('CLEAN'));
        return;
    }
    steps = only ? 2 : 6;
    const rev = mode.rev;
    const checksum = mode.checksum;
    fs.mkdirSync(OBJ, { recursive: true });

    // 1. prebuild: ROM check (path, SHA-1, size) and Extracted/ assets.
    {
        begin('prebuild');
        const r = await node('prebuild.js', [only ? 'dev' : mode.prebuild]);
        if (r.status !== 0) fail('prebuild', 'ROM or asset extraction', r.out);
        let count = '?';
        try { count = JSON.parse(fs.readFileSync(path.join(ROOT, 'Extracted', '.extract-complete.json'), 'utf8')).files.length; } catch (e) { /* keep ? */ }
        step('prebuild', `ROM OK, ${count} assets extracted`);
        detail(r.out);
    }

    // 2-3. EA logo and sound driver, included by the main ROM from output/ (copied there from output/<mode>/obj/).
    if (only !== 'sound') await subBuild('logo', 'EALogo.asm', 'EALogo', '.bin', rev, checksum);
    if (only !== 'logo') await subBuild('sound', 'sound\\sound.asm', 'Hockey', '.snd', rev, checksum);
    if (only) return;

    // 4. assemble: the main ROM.
    begin('assemble');
    const a = await assemble('assemble', 'hockey.asm', `..\\output\\${modeName}\\obj\\nhl92`, '.bin', rev, checksum);
    step('assemble', `${a.errors} errors, ${a.warnings} warnings, ${a.lines} lines in ${a.secs}s (REV=${rev} CHECKSUM=${checksum}) -> ${rel(a.bin)}`);

    // 5. fixopcodes: the result is output/<mode>/nhl92.bin.
    begin('fixopcodes');
    const f = await fixopcodes('fixopcodes', a);
    const final = path.join(OUT, ROM);
    fs.renameSync(f.fixed, final);
    step('fixopcodes', `${f.count} opcodes fixed${f.skipped ? `, ${f.skipped} skipped` : ''} -> ${rel(final)}`);

    // 6. verify against the reference ROM.
    if (!mode.ref) { step('verify', `${rel(final)} not verified (dev build)`); return; }
    begin('verify');
    const r = await node('verifyRom.js', [final, mode.ref]);
    const first = r.out.split(/\r?\n/).find((l) => l.trim()) || '';
    if (r.status !== 0 || !/^MATCH/.test(first)) fail('verify', rel(final), r.out, 'MISMATCH');
    step('verify', `MATCH ${rel(final)} == ${mode.ref}`);
    detail(r.out);
})();
