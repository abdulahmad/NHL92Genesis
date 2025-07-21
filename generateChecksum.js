const fs = require('fs').promises;

const endoffile = 0x7FE8A;
const checksumoffset = 0x20; // insert checksum here
async function calculateChecksums(romPath) {
    try {
        // Read the ROM file
        const rom = await fs.readFile(romPath);
        if (rom.length !== 0x80000) {
            console.warn(`Warning: ROM size is ${rom.length} bytes, expected 512 KB (524288 bytes)`);
        }

        // 16-bit Checksum (ROM Header, 0x200 to 0x80000)
        function calculate16BitChecksum() {
            let sum = 0;
            // Start at 0x200, sum 16-bit words
            for (let i = 0x200; i < rom.length; i += 2) {
                // Read 16-bit word (big-endian)
                const word = (rom[i] << 8) | rom[i + 1];
                sum = (sum + word) & 0xFFFF; // Keep lower 16 bits
                // console.log('16', sum);
            }
            return sum;
        }

        // 32-bit Checksum (Security Routine, 0x0000 to 0x7FE8A, skip 0x18C–0x18F)
        function calculate32BitChecksum() {
            let sum = 0n; // Use BigInt for 32-bit arithmetic
            // Process 32-bit longwords
            for (let i = 0; i < endoffile; i += 4) {
                // Skip 0x18C to 0x18F (4 bytes)
                if (i === 0x18C) {
                    continue;
                }
                // Read 32-bit longword (big-endian)
                const longword =
                    (rom[i] << 24) |
                    (rom[i + 1] << 16) |
                    (rom[i + 2] << 8) |
                    rom[i + 3];
                // console.log('32', sum);
                sum += BigInt(longword >>> 0); // Unsigned 32-bit addition
            }
            // Convert to 32-bit unsigned integer
            return Number(sum & 0xFFFFFFFFn);
        }

        // Calculate checksums
        const checksum16 = calculate16BitChecksum();
        const checksum32 = calculate32BitChecksum();

        // Output results in hexadecimal
        console.log(`16-bit Checksum (at 0x18E): 0x${checksum16.toString(16).padStart(4, '0').toUpperCase()} <-- this should be generated against checksum=1 w/32-bit checksum updated`);
        console.log(`32-bit Checksum: 0x${checksum32.toString(16).padStart(8, '0').toUpperCase()} <-- this should be generated against checksum=1`);

        return { checksum16, checksum32 };
    } catch (error) {
        console.error('Error:', error.message);
        throw error;
    }
}

// Example usage
const romPath = 'output/modified_nhl92.bin'; // Replace with your ROM file path
calculateChecksums(romPath).catch(() => process.exit(1));