'use strict';

// Helpers for SNASM68k assemble failures. Used by tools/build.js.
//
// A PC-relative branch out of range shows up two ways in SNASM's output:
//   forward target:  FILE.ASM(n) Branch (36866 bytes) is out of range
//   backward target: FILE.ASM(n) Illegal value (-36866)
// "Illegal value" also covers unrelated errors, so it only counts as a branch when the source line is a
// bra/bsr/Bcc/DBcc instruction. SNASM echoes that source line right after the error; when the echo is
// missing, the line is read from the file SNASM names. (The line number in the error can run into the
// command-line text, e.g. HOCKEY93.ASM(70313.bin for line 7031, so the echo is the reliable source.)

const fs = require('fs');
const path = require('path');

const DEFAULT_DOC = 'docs/EXPANDING_THE_ROM.md';
const CC = 'hi|ls|cc|hs|cs|lo|ne|eq|vc|vs|pl|mi|ge|lt|gt|le';
const BRANCH_RE = new RegExp(`^(?:bra|bsr|b(?:${CC})|db(?:t|f|ra|${CC}))(?:\\.[bswl])?$`, 'i');
const LOCATION_RE = /([A-Za-z]:\\[^()\r\n]*?\.(?:asm|inc|mac)|[^\s()]+\.(?:asm|inc|mac))\((\d+)/i;

function filterAssemblerErrors(lines) {
    return lines.filter((l) => /\.(asm|inc|mac)\(\d+|error|fatal|not recognised|undefined|could not/i.test(l) && !/error\(s\) from/.test(l)).slice(0, 40);
}

// Find a file whose name SNASM printed (upper case, a Windows path; Z: is / under wine).
function resolveSourcePath(file, cwd) {
    if (fs.existsSync(file)) return file;
    let p = file;
    const drive = /^([A-Za-z]):\\(.*)$/.exec(file);
    if (drive) {
        if (drive[1].toUpperCase() !== 'Z') return null;
        p = '/' + drive[2];
    } else if (cwd) {
        p = path.join(cwd, file);
    }
    const parts = p.split(/[\\/]+/).filter(Boolean);
    let cur = path.isAbsolute(p) || drive ? path.sep : '';
    for (const part of parts) {
        let entries;
        try { entries = fs.readdirSync(cur || '.'); } catch (e) { return null; }
        const hit = entries.find((e) => e === part) || entries.find((e) => e.toLowerCase() === part.toLowerCase());
        if (!hit) return null;
        cur = path.join(cur, hit);
    }
    return cur;
}

function sourceLine(file, lineNo, cwd) {
    const p = resolveSourcePath(file, cwd);
    if (!p) return null;
    try {
        return fs.readFileSync(p, 'latin1').split(/\r\n|\n|\r/)[lineNo - 1] ?? null;
    } catch (e) {
        return null;
    }
}

// True when the source line is a PC-relative branch (label, optional colon, then bra/bsr/Bcc/DBcc).
function isBranchSource(text) {
    if (text == null) return false;
    const code = text.replace(/;.*$/, '');
    const tokens = code.trim().split(/\s+/).filter(Boolean);
    if (!tokens.length) return false;
    if (/^\s/.test(code) || BRANCH_RE.test(tokens[0])) return BRANCH_RE.test(tokens[0]);
    return tokens.length > 1 && BRANCH_RE.test(tokens[1]);
}

function isIllegalValueBranch(line, echo, options = {}) {
    if (!/Illegal value/i.test(line)) return false;
    if (echo != null && echo.trim() && !LOCATION_RE.test(echo) && !/error|aborted|completed/i.test(echo)) {
        return isBranchSource(echo);
    }
    const m = LOCATION_RE.exec(line);
    if (!m) return false;
    return isBranchSource(sourceLine(m[1], Number(m[2]), options.cwd));
}

function hasBranchOutOfRange(lines, options = {}) {
    const list = Array.isArray(lines) ? lines : String(lines).split(/\r\n|\n|\r/);
    const text = list.join('\n');
    if (/branch\s*\([^)]*\)\s*is out of range/i.test(text)
        || (/out of range/i.test(text) && /branch/i.test(text))) return true;
    return list.some((l, i) => isIllegalValueBranch(l, list[i + 1], options));
}

function expandingRomBranchHint(options = {}) {
    const doc = options.doc || DEFAULT_DOC;
    const fill = options.fillHint || 'the stock ROM fill in the top-level .asm include list';
    return [
        '',
        'Branch out of range (68000 PC-relative limit ~±32 KB):',
        `  • Do not insert new ROM between existing modules if later code is branched to with .w — put new data after ${fill}.`,
        '  • From retail code into post-fill code, use jsr (label).l / jmp (label).l.',
        '  • In new post-fill code, use .l calls or a local rts instead of bsr.w to distant labels.',
        `  • Read ${doc} (Short jumps — PC-relative branches).`,
    ].join('\n');
}

function formatAssemblerFailureDetail(lines, options = {}) {
    let detail = filterAssemblerErrors(lines).join('\n');
    if (hasBranchOutOfRange(lines, options)) detail += expandingRomBranchHint(options);
    return detail;
}

module.exports = {
    DEFAULT_DOC,
    filterAssemblerErrors,
    resolveSourcePath,
    isBranchSource,
    isIllegalValueBranch,
    hasBranchOutOfRange,
    expandingRomBranchHint,
    formatAssemblerFailureDetail,
};
