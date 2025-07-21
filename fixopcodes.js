const fs = require('fs').promises;
const path = require('path');

// Define the opcode replacement table
const opcodeReplacements = [
    { instruction: 'cmp', existingOpcode: '0C00', newOpcode: 'B03C' },
    { instruction: 'cmp.w', existingOpcode: '0C40', newOpcode: 'B07C' },
    { instruction: 'cmpi.w', existingOpcode: '0C40', newOpcode: 'B07C' },
    { instruction: 'cmp', existingOpcode: '0C40', newOpcode: 'B07C' },
    { instruction: 'cmp', existingOpcode: '0C41', newOpcode: 'B27C' },
    { instruction: 'cmp', existingOpcode: '0C42', newOpcode: 'B47C' },
    { instruction: 'cmp', existingOpcode: '0C43', newOpcode: 'B67C' },
    { instruction: 'cmp', existingOpcode: '0C44', newOpcode: 'B87C' },
    { instruction: 'cmp', existingOpcode: '0C45', newOpcode: 'BA7C' },
    { instruction: 'cmp', existingOpcode: '0C46', newOpcode: 'BC7C' },
    { instruction: 'cmp.b', existingOpcode: '0C07', newOpcode: 'BE3C' },
    { instruction: 'cmp', existingOpcode: '0C47', newOpcode: 'BE7C' },
    { instruction: 'cmpi.l', existingOpcode: '0C80', newOpcode: 'B0BC' },
    { instruction: 'cmp.l', existingOpcode: '0C80', newOpcode: 'B0BC' },
    { instruction: 'cmpi.l', existingOpcode: '0C81', newOpcode: 'B2BC' },
    { instruction: 'cmpi.l', existingOpcode: '0C83', newOpcode: 'B6BC' },
    { instruction: 'exg', existingOpcode: 'C34A', newOpcode: 'C549', operandCondition: (operands) => /^\s*a2\s*,\s*a1\s*$/.test(operands) },
    { instruction: 'exg', existingOpcode: 'C141', newOpcode: 'C340', operandCondition: (operands) => /^\s*d1\s*,\s*d0\s*$/.test(operands) },
    // do not change: exg	d0,d1
    // do change: exg	d1,d0
];

// Function to parse the .lst file
async function parseListingFile(lines, opcodeReplacements) {
    const matches = [];
    for (const replacement of opcodeReplacements) {
        const { instruction, existingOpcode, newOpcode, operandCondition } = replacement;
        // Updated regex to support optional labels
        const regex = new RegExp(
            `^\\s*([0-9A-Fa-f]{8})` +                             // address
            `\\s+([0-9A-Fa-f]{4}(?:\\s+[0-9A-Fa-f]{4})*)` +        // hex words
            `\\s*(?:(\\.?[A-Za-z0-9_]+)\\s+)?` +                  // optional label, allowing a leading dot
            `${instruction}\\b` +                                 // the mnemonic (with word-boundary)
            `\\s*([^;]*)(?:;.*)?(?:\\r)?$`,                       // operands + optional comment + CR
            'i'
        );


        for (const line of lines) {
            // Use a platform-independent path comparison in regex
            if (/\s*incbin\s+..[\\\/]Extracted[\\\/]Sound[\\\/]Hockey\.snd/i.test(line)) {
                console.log(`Hit incbin directive, stopping scan for ${instruction}`);
                break;       // stop processing any more lines for this replacement
            }

            const match = line.match(regex);
            if (match) {
                // Extract fields from the regex match
                const offset = parseInt(match[1], 16);           // Address
                const hexCodes = match[2].split(/\s+/);          // Hex words (opcode + additional)
                const opcode = hexCodes[0].toUpperCase();        // First hex word as opcode
                const label = match[3] ? match[3].trim() : '';   // Label, if present
                const operands = match[4] ? match[4].trim() : ''; // Operands

                // Check if the opcode matches and operand condition (if any) is satisfied
                if (opcode === existingOpcode.toUpperCase()) {
                    if (!operandCondition || operandCondition(operands)) {
                        matches.push({ offset, newOpcode });
                        console.log(
                            `Matched ${instruction} at offset 0x${offset.toString(16).padStart(8, '0').toUpperCase()} with opcode ${opcode}`
                        );
                    }
                }
            } else if (line && (line.includes(existingOpcode.toUpperCase()) || line.includes(existingOpcode.toLowerCase()))) {
                // Debug output for unmatched lines containing the opcode
                const rawLine = line.replace(/\t/g, '\\t').replace(/\r/g, '\\r').replace(/\n/g, '\\n');
                console.log(`DEBUG: Failed to match '${rawLine}' with ${instruction} (opcode ${existingOpcode})`);
            }
        }
    }
    return matches;
}

// Function to modify the binary file
async function modifyBinaryFile(binFilePath, matches) {
    const binaryData = await fs.readFile(binFilePath);
    const buffer = Buffer.from(binaryData);

    for (const { offset, newOpcode } of matches) {
        if (offset + 2 > buffer.length) {
            console.warn(`Warning: Offset 0x${offset.toString(16).padStart(8, '0').toUpperCase()} is beyond binary file length. Skipping.`);
            continue;
        }
        const currentOpcode = buffer.readUInt16BE(offset);
        const expectedOpcode = parseInt(
            opcodeReplacements.find((r) => r.newOpcode.toUpperCase() === newOpcode.toUpperCase()).existingOpcode,
            16
        );
        if (currentOpcode === expectedOpcode) {
            const newOpcodeValue = parseInt(newOpcode, 16);
            buffer.writeUInt16BE(newOpcodeValue, offset);
            console.log(
                `Modified opcode at offset 0x${offset.toString(16).padStart(8, '0').toUpperCase()} from ${currentOpcode.toString(16).padStart(4, '0').toUpperCase()} to ${newOpcode.toUpperCase()}`
            );
        } else {
            console.warn(
                `Warning: Opcode at offset 0x${offset.toString(16).padStart(8, '0').toUpperCase()} is 0x${currentOpcode.toString(16).padStart(4, '0').toUpperCase()}, expected 0x${expectedOpcode.toString(16).padStart(4, '0').toUpperCase()}. Skipping.`
            );
        }
    }

    const outputPath = path.join(path.dirname(binFilePath), `modified_${path.basename(binFilePath)}`);
    await fs.writeFile(outputPath, buffer);
    console.log(`Modified binary written to ${outputPath}`);
}

// Main function
async function main() {
    try {
        const [lstFilePath, binFilePath] = process.argv.slice(2);

        if (!lstFilePath || !binFilePath) {
            console.error('Usage: node script.js <listing.lst> <binary.bin>');
            process.exit(1);
        }

        const data = await fs.readFile(lstFilePath, 'utf8');
        const lines = data.split('\n');

        console.log(`Parsing listing file: ${lstFilePath} with ${lines.length} lines`);
        const matches = await parseListingFile(lines, opcodeReplacements);
        console.log(`Found ${matches.length} instructions to modify`);

        if (matches.length === 0) {
            console.log('No modifications needed.');
            return;
        }

        console.log(`Modifying binary file: ${binFilePath}`);
        await modifyBinaryFile(binFilePath, matches);
        console.log(`Modified ${matches.length} instructions`);
    } catch (error) {
        console.error('Script failed:', error.message);
        process.exit(1);
    }
}

// Run the script
main();