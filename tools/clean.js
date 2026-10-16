// clean.js: delete build outputs. Usage: node tools/clean.js [--all]
// Removes output/. With --all also removes Extracted/ (re-extracted by tools/prebuild.js on the next build).
// Never touches the ROM files.
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const dirs = ['output'];
if (process.argv.includes('--all')) dirs.push('Extracted');
for (const d of dirs) {
    const p = path.join(ROOT, d);
    if (fs.existsSync(p)) {
        fs.rmSync(p, { recursive: true, force: true });
        console.log(`clean: removed ${d}/`);
    }
}
