#!/usr/bin/env node
// build.js: the whole NHL 92 build, one line per step, on Windows and on Linux/macOS (wine).
// Replaces build.bat / buildEALogo.bat / buildSound.bat (as in NHL94Genesis tools/build.js).
//   node tools/build.js [retail|reva|dev] [--verbose]   full ROM -> output/nhl92.bin, nhl92-revA.bin or nhl92-dev.bin
//   node tools/build.js --logo | --sound [--verbose]    only the EA logo (output/modified_EALogo.bin) or the sound
//                                                       driver (output/modified_Hockey.snd)
//   node tools/build.js --clean                         delete output/ and Extracted/
// retail: REV=0 CHECKSUM=1, verified against nhl92retail.bin. reva: REV=1 CHECKSUM=1, verified against
// nhl92retailRevA.bin. dev: REV=1 CHECKSUM=0 (no validation routine), not verified.
// The main ROM includes output/modified_EALogo.bin and output/modified_Hockey.snd, so those are built first.
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'output');
const BUILD = path.join(OUT, 'build');
const WIN = process.platform === 'win32';
const EXE = path.join(ROOT, 'assembler', 'Assembler.exe');
const MODES = {
    retail: { rev: 0, checksum: 1, prebuild: 'retail', ref: 'nhl92retail.bin', final: 'nhl92.bin' },
    reva: { rev: 1, checksum: 1, prebuild: 'reva', ref: 'nhl92retailRevA.bin', final: 'nhl92-revA.bin' },
    dev: { rev: 1, checksum: 0, prebuild: 'dev', ref: null, final: 'nhl92-dev.bin' },
};

const args = process.argv.slice(2);
const verbose = args.includes('--verbose');
const modeName = args.find((a) => MODES[a]) || 'retail';
const mode = MODES[modeName];
const only = args.includes('--logo') ? 'logo' : args.includes('--sound') ? 'sound' : null;
const rel = (p) => path.relative(ROOT, p).split(path.sep).join('/');

let n = 0;
let steps = 0;
const step = (name, text) => console.log(`[${++n}/${steps}] ${name.padEnd(10)} ${text}`);
function fail(name, text, log) {
    console.log(`[${++n}/${steps}] ${name.padEnd(10)} FAILED: ${text}`);
    if (log) console.log(log.replace(/\s+$/, '').replace(/^/gm, '    '));
    console.log(`BUILD FAILED at ${name}`);
    process.exit(1);
}
const detail = (t) => { if (verbose && t.trim()) console.log(t.replace(/\s+$/, '').replace(/^/gm, '    ')); };

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
    return { bin: base + binExt, lst: `${base} .lst`, lines: sum[2], secs: sum[3] };
}

// fixopcodes: rewrite the cmp / exg encodings where SNASM picks a different one than EA's assembler.
async function fixopcodes(name, a) {
    const r = await node('fixopcodes.js', [a.lst, a.bin]);
    const m = r.out.match(/Modified (\d+) instructions/);
    const fixed = path.join(path.dirname(a.bin), `modified_${path.basename(a.bin)}`);
    if (r.status !== 0 || !m || !fs.existsSync(fixed)) fail(name, 'fixopcodes did not write the fixed binary', r.out);
    detail(r.out);
    return { fixed, count: m[1] };
}

async function subBuild(name, src, base, ext, rev, checksum) {
    const a = await assemble(name, src, `..\\output\\${base}`, ext, rev, checksum);
    const f = await fixopcodes(name, a);
    step(name, `${a.lines} lines, ${f.count} opcodes fixed -> ${rel(f.fixed)}`);
}

(async () => {
    if (args.includes('--clean')) {
        steps = 2;
        for (const dir of ['output', 'Extracted']) {
            const full = path.join(ROOT, dir);
            const had = fs.existsSync(full);
            fs.rmSync(full, { recursive: true, force: true });
            step(dir, had ? 'removed' : 'already clean');
        }
        console.log('CLEAN');
        return;
    }
    steps = only ? 2 : 6;
    const rev = only ? 0 : mode.rev;
    const checksum = only ? 1 : mode.checksum;
    fs.mkdirSync(BUILD, { recursive: true });

    // 1. prebuild: ROM check (path, SHA-1, size) and Extracted/ assets.
    {
        const r = await node('prebuild.js', [only ? 'dev' : mode.prebuild]);
        if (r.status !== 0) fail('prebuild', 'ROM or asset extraction', r.out);
        let count = '?';
        try { count = JSON.parse(fs.readFileSync(path.join(ROOT, 'Extracted', '.extract-complete.json'), 'utf8')).files.length; } catch (e) { /* keep ? */ }
        step('prebuild', `ROM OK, ${count} assets in Extracted/`);
        detail(r.out);
    }

    // 2-3. EA logo and sound driver, included by the main ROM from output/.
    if (only !== 'sound') await subBuild('logo', 'EALogo.asm', 'EALogo', '.bin', rev, checksum);
    if (only !== 'logo') await subBuild('sound', 'sound\\sound.asm', 'Hockey', '.snd', rev, checksum);
    if (only) return;

    // 4-5. main ROM, then fixopcodes; the result is output/<final>.
    const a = await assemble('assemble', 'hockey.asm', '..\\output\\build\\nhl92', '.bin', rev, checksum);
    step('assemble', `0 errors, ${a.lines} lines in ${a.secs}s (REV=${rev} CHECKSUM=${checksum}) -> ${rel(a.bin)}`);
    const f = await fixopcodes('fixopcodes', a);
    const final = path.join(OUT, mode.final);
    fs.renameSync(f.fixed, final);
    step('fixopcodes', `${f.count} opcodes fixed -> ${rel(final)}`);

    // 6. verify against the reference ROM.
    if (!mode.ref) { step('verify', `${rel(final)} not verified (dev build)`); return; }
    const r = await node('verifyRom.js', [final, mode.ref]);
    const first = r.out.split(/\r?\n/).find((l) => l.trim()) || '';
    if (r.status !== 0 || !/^MATCH/.test(first)) fail('verify', rel(final), r.out);
    step('verify', `MATCH ${rel(final)} == ${mode.ref}`);
})();
