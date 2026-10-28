'use strict';

// Helpers for SNASM68k assemble failures. Used by tools/build.js.

const DEFAULT_DOC = 'docs/EXPANDING_THE_ROM.md';

function filterAssemblerErrors(lines) {
    return lines.filter((l) => /\.(asm|inc|mac)\(\d+|error|fatal|not recognised|undefined|could not/i.test(l) && !/error\(s\) from/.test(l)).slice(0, 40);
}

function hasBranchOutOfRange(lines) {
    const text = (Array.isArray(lines) ? lines : [lines]).join('\n');
    return /branch\s*\([^)]*\)\s*is out of range/i.test(text)
        || (/out of range/i.test(text) && /branch/i.test(text));
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
    if (hasBranchOutOfRange(lines)) detail += expandingRomBranchHint(options);
    return detail;
}

module.exports = {
    DEFAULT_DOC,
    filterAssemblerErrors,
    hasBranchOutOfRange,
    expandingRomBranchHint,
    formatAssemblerFailureDetail,
};
