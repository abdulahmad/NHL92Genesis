const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

// Asset definitions from the .lst file
const assets = [
    { name: 'EALogo.bin', folder: 'Graphics', start: 0x00000306, end: 0x00001164 },
    { name: 'EALogo.WordmarkAnimationTable.bin', folder: 'Graphics', start: 0x00000D58, end: 0x0000D61 },
    { name: 'EALogo.WordmarkPositionTable.bin', folder: 'Graphics', start: 0x00000D61, end: 0x0000D7C },
    { name: 'EALogo.WordmarkOffsetTable.bin', folder: 'Graphics', start: 0x00000D7C, end: 0x0000D85 },
    { name: 'EALogo.WordmarkFadeTable.bin', folder: 'Graphics', start: 0x00000D85, end: 0x0000D8E },
    { name: 'EALogo.LogoAnimationTable.bin', folder: 'Graphics', start: 0x00000D8E, end: 0x00001164 },
    { name: 'Bruinsh.pal', folder: 'Graphics/Pals', start: 0x000011DA, end: 0x000011FA },
    { name: 'Bruinsv.pal', folder: 'Graphics/Pals', start: 0x000011FA, end: 0x0000121A },
    { name: 'sabresh.pal', folder: 'Graphics/Pals', start: 0x00001320, end: 0x00001340 },
    { name: 'sabresv.pal', folder: 'Graphics/Pals', start: 0x00001340, end: 0x00001360 },
    { name: 'flamesh.pal', folder: 'Graphics/Pals', start: 0x00001466, end: 0x00001486 },
    { name: 'flamesv.pal', folder: 'Graphics/Pals', start: 0x00001486, end: 0x000014A6 },
    { name: 'blackhawksh.pal', folder: 'Graphics/Pals', start: 0x000015BC, end: 0x000015DC },
    { name: 'blackhawksv.pal', folder: 'Graphics/Pals', start: 0x000015DC, end: 0x000015FC },
    { name: 'Redwingsh.pal', folder: 'Graphics/Pals', start: 0x00001716, end: 0x00001736 },
    { name: 'Redwingsv.pal', folder: 'Graphics/Pals', start: 0x00001736, end: 0x00001756 },
    { name: 'oilersh.pal', folder: 'Graphics/Pals', start: 0x00001878, end: 0x00001898 },
    { name: 'oilersv.pal', folder: 'Graphics/Pals', start: 0x00001898, end: 0x000018B8 },
    { name: 'whalersh.pal', folder: 'Graphics/Pals', start: 0x000019C8, end: 0x000019E8 },
    { name: 'whalersv.pal', folder: 'Graphics/Pals', start: 0x000019E8, end: 0x00001A08 },
    { name: 'Kingsh.pal', folder: 'Graphics/Pals', start: 0x00001B00, end: 0x00001B20 },
    { name: 'Kingsv.pal', folder: 'Graphics/Pals', start: 0x00001B20, end: 0x00001B40 },
    { name: 'northstarsh.pal', folder: 'Graphics/Pals', start: 0x00001C52, end: 0x00001C72 },
    { name: 'northstarsv.pal', folder: 'Graphics/Pals', start: 0x00001C72, end: 0x00001C92 },
    { name: 'canadiensh.pal', folder: 'Graphics/Pals', start: 0x00001DA8, end: 0x00001DC8 },
    { name: 'canadiensv.pal', folder: 'Graphics/Pals', start: 0x00001DC8, end: 0x00001DE8 },
    { name: 'devilsh.pal', folder: 'Graphics/Pals', start: 0x00001EEA, end: 0x00001F0A },
    { name: 'devilsv.pal', folder: 'Graphics/Pals', start: 0x00001F0A, end: 0x00001F2A },
    { name: 'islandersh.pal', folder: 'Graphics/Pals', start: 0x0000203C, end: 0x0000205C },
    { name: 'islandersv.pal', folder: 'Graphics/Pals', start: 0x0000205C, end: 0x0000207C },
    { name: 'rangersh.pal', folder: 'Graphics/Pals', start: 0x00002186, end: 0x000021A6 },
    { name: 'rangersv.pal', folder: 'Graphics/Pals', start: 0x000021A6, end: 0x000021C6 },
    { name: 'flyersh.pal', folder: 'Graphics/Pals', start: 0x000022D6, end: 0x000022F6 },
    { name: 'flyersv.pal', folder: 'Graphics/Pals', start: 0x000022F6, end: 0x00002316 },
    { name: 'penguinsh.pal', folder: 'Graphics/Pals', start: 0x0000242A, end: 0x0000244A },
    { name: 'penguinsv.pal', folder: 'Graphics/Pals', start: 0x0000244A, end: 0x0000246A },
    { name: 'nordiquesh.pal', folder: 'Graphics/Pals', start: 0x00002576, end: 0x00002596 },
    { name: 'nordiquesv.pal', folder: 'Graphics/Pals', start: 0x00002596, end: 0x000025B6 },
    { name: 'Sharksh.pal', folder: 'Graphics/Pals', start: 0x000026BE, end: 0x000026DE },
    { name: 'Sharksv.pal', folder: 'Graphics/Pals', start: 0x000026DE, end: 0x000026FE },
    { name: 'bluesh.pal', folder: 'Graphics/Pals', start: 0x00002806, end: 0x00002826 },
    { name: 'bluesv.pal', folder: 'Graphics/Pals', start: 0x00002826, end: 0x00002846 },
    { name: 'mapleleafsh.pal', folder: 'Graphics/Pals', start: 0x00002946, end: 0x00002966 },
    { name: 'mapleleafsv.pal', folder: 'Graphics/Pals', start: 0x00002966, end: 0x00002986 },
    { name: 'canucksh.pal', folder: 'Graphics/Pals', start: 0x00002A92, end: 0x00002AB2 },
    { name: 'canucksv.pal', folder: 'Graphics/Pals', start: 0x00002AB2, end: 0x00002AD2 },
    { name: 'capitalsh.pal', folder: 'Graphics/Pals', start: 0x00002BEC, end: 0x00002C0C },
    { name: 'capitalsv.pal', folder: 'Graphics/Pals', start: 0x00002C0C, end: 0x00002C2C },
    { name: 'jetsh.pal', folder: 'Graphics/Pals', start: 0x00002D30, end: 0x00002D50 },
    { name: 'jetsv.pal', folder: 'Graphics/Pals', start: 0x00002D50, end: 0x00002D70 },
    { name: 'Campbellh.pal', folder: 'Graphics/Pals', start: 0x00002E7E, end: 0x00002E9E },
    { name: 'Campbellv.pal', folder: 'Graphics/Pals', start: 0x00002E9E, end: 0x00002EBE },
    { name: 'Walesh.pal', folder: 'Graphics/Pals', start: 0x00002FB8, end: 0x00002FD8 },
    { name: 'Walesv.pal', folder: 'Graphics/Pals', start: 0x00002FD8, end: 0x00002FF8 },
    { name: 'Hockey.snd', folder: 'Sound', start: 0x0000F4C8, end: 0x00024214 },
    // snd 68k code: F4C8 - FA92
    { name: 'sfx_header_table.bin', folder: 'Sound', start: 0xFA92, end: 0xFB1E },
    // snd 68k code 2 (including sfx handlers): FB1E - FF72
    { name: 'sfx_siren_cmdstream_ch0.bin', folder: 'Sound', start: 0xFF74, end: 0xFF90 },
    { name: 'sfx_siren_cmdstream_ch1.bin', folder: 'Sound', start: 0xFF90, end: 0xFFB8 },
    { name: 'sfx_puckfaceoff_cmdstream.bin', folder: 'Sound', start: 0xFFB8, end: 0xFFC8 },
    { name: 'sfx_whistle_cmdstream.bin', folder: 'Sound', start: 0xFFC8, end: 0xFFF0 },
    { name: 'sfx_hitpuck_cmdstream.bin', folder: 'Sound', start: 0xFFF0, end: 0x1000E },
    { name: 'sfx_post_cmdstream.bin', folder: 'Sound', start: 0x1000E, end: 0x1002C },
    { name: 'sfx_foghorn_cmdstream_ch0.bin', folder: 'Sound', start: 0x1002C, end: 0x10054 },
    { name: 'sfx_foghorn_cmdstream_ch1.bin', folder: 'Sound', start: 0x10054, end: 0x10088 },
    { name: 'sfx_whiff_cmdstream.bin', folder: 'Sound', start: 0x10088, end: 0x100A6 }, // there is a stop at 100A0?
    { name: 'sfx_hitboard1_cmdstream.bin', folder: 'Sound', start: 0x100A6, end: 0x100C4 }, // also chained from SFX 15-17 (player hits boards)
    { name: 'sfx_hitboardquiet1_cmdstream.bin', folder: 'Sound', start: 0x100C4, end: 0x100E2 },
    { name: 'sfx_hitboardquiet2_cmdstream.bin', folder: 'Sound', start: 0x100E2, end: 0x10100 },
    { name: 'sfx_hitboard2_cmdstream.bin', folder: 'Sound', start: 0x10100, end: 0x1011E },
    { name: 'sfx_hitboardquiet3_cmdstream.bin', folder: 'Sound', start: 0x1011E, end: 0x1013C },
    { name: 'sfx_hitboardquiet4_cmdstream.bin', folder: 'Sound', start: 0x1013C, end: 0x1015A },
    { name: 'sfx_skate2_cmdstream.bin', folder: 'Sound', start: 0x1015A, end: 0x1016A },
    { name: 'sfx_skate1_cmdstream.bin', folder: 'Sound', start: 0x1016A, end: 0x1017A },
    { name: 'note_freqeuency_table.bin', folder: 'Sound', start: 0x1017A, end: 0x101DA },
    { name: 'note_octave_table.bin', folder: 'Sound', start: 0x101DA, end: 0x1023A },
    { name: 'envelope_table.bin', folder: 'Sound', start: 0x1023A, end: 0x10294 },
    { name: 'fmtune_header_table.bin', folder: 'Sound', start: 0x10294, end: 0x10316 },
    { name: 'fmtune_channel_data.bin', folder: 'Sound', start: 0x10316, end: 0x1061E }, // the data changes around 1061E
    { name: 'fmtune_sequence_data.bin', folder: 'Sound', start: 0x1061E, end: 0x11624 },
    // code segment 3 0x11624 - 0x116A6
    { name: 'z80_snd_drv.bin', folder: 'Sound', start: 0x116A6, end: 0x11C3E },
    { name: 'sfx_slapshot_pcm.bin', folder: 'Sound', start: 0x11C3E, end: 0x12A58 },
    { name: 'sfx_pass2_pcm.bin', folder: 'Sound', start: 0x12A58, end: 0x13960 },
    { name: 'sfx_pass1_pcm.bin', folder: 'Sound', start: 0x13960, end: 0x14886 },
    { name: 'sfx_playerboards_pcm.bin', folder: 'Sound', start: 0x14886, end: 0x15768 }, // SFX 15-17 (player hits boards)
    { name: 'sfx_check_pcm.bin', folder: 'Sound', start: 0x15768, end: 0x168AA }, // SFX 18-20 (checks)
    { name: 'sfx_punch_pcm.bin', folder: 'Sound', start: 0x168AA, end: 0x16E04 }, // offset in code is 168B0; SFX 21-23 (punches)
    { name: 'sfx_crowdcheer_pcm.bin', folder: 'Sound', start: 0x16E04, end: 0x1D786 },
    { name: 'sfx_boo_pcm.bin', folder: 'Sound', start: 0x1D786, end: 0x1FCE8 },
    { name: 'sfx_oooh_pcm.bin', folder: 'Sound', start: 0x1FCE8, end: 0x222AA }, // SFX 31 (oooh), offset in code is 1FD88
    // is there a break at 0x1FFA3?
    { name: 'sfx_skate34_pcm.bin', folder: 'Sound', start: 0x222AA, end: 0x00024214 }, // SFX 3-4 (skating 3 and 4)
    

    { name: 'GameSetUp.map.jim', folder: 'Graphics', start: 0x00024214, end: 0x00025642 },
    { name: 'Title1.map.jim', folder: 'Graphics', start: 0x00025642, end: 0x0002ADF0 },
    { name: 'Title2.map.jim', folder: 'Graphics', start: 0x0002ADF0, end: 0x0002C0FE },
    { name: 'NHLSpin.map.jim', folder: 'Graphics', start: 0x0002C0FE, end: 0x0002E9EC },
    { name: 'Puck.anim', folder: 'Graphics', start: 0x0002E9EC, end: 0x0002F262 },
    { name: 'Scouting.map.jim', folder: 'Graphics', start: 0x0002F262, end: 0x00033590 },
    { name: 'Framer.map.jim', folder: 'Graphics', start: 0x00033590, end: 0x000336B0 },
    { name: 'FaceOff.map.jim', folder: 'Graphics', start: 0x000336B0, end: 0x00033AAE },
    { name: 'IceRink.map.jim', folder: 'Graphics', start: 0x00033AAE, end: 0x0003A3DC },
    { name: 'Refs.map.jim', folder: 'Graphics', start: 0x0003A3DC, end: 0x0003D5EE },
    { name: 'Sprites.anim', folder: 'Graphics', start: 0x0003D5EE, end: 0x0007216C },
    { name: 'Crowd.anim', folder: 'Graphics', start: 0x0007216C, end: 0x00075790 },
    { name: 'FaceOff.anim', folder: 'Graphics', start: 0x00075790, end: 0x0007716C },
    { name: 'Zam.anim', folder: 'Graphics', start: 0x0007716C, end: 0x000778D2 },
    { name: 'BigFont.map.jim', folder: 'Graphics', start: 0x000778D2, end: 0x00078C20 },
    { name: 'SmallFont.map.jim', folder: 'Graphics', start: 0x00078C20, end: 0x00079C2E },
    { name: 'TeamBlocks.map.jim', folder: 'Graphics', start: 0x00079C2E, end: 0x0007E79C },
    { name: 'Arrows.map.jim', folder: 'Graphics', start: 0x0007E79C, end: 0x0007EB12 },
    { name: 'Stanley.map.jim', folder: 'Graphics', start: 0x0007EB12, end: 0x0007FC20 },
    { name: 'EASN.map.jim', folder: 'Graphics', start: 0x0007FC20, end: 0x0007FE8A }
];

// Supported ROM. The assets are sliced from the retail ROM; the Rev A build uses the same assets.
const VERSIONS = [
    { id: 'retail', label: 'NHL Hockey (NHL 92) retail (1991.MAY, GM T-50236 -00)', file: 'nhl92retail.bin',
      sha1: '2337ad3c065f46edccf19007d7a5be80a97520d5', size: 0x80000 },
];

// Find the version of a ROM by SHA-1.
function detectVersion(data) {
    const sha1 = crypto.createHash('sha1').update(data).digest('hex');
    const v = VERSIONS.find((x) => x.sha1 === sha1);
    if (v) return { version: v, sha1 };
    let msg = `Unknown ROM: SHA-1 ${sha1}, ${data.length} bytes.\n`;
    msg += 'Assets are extracted from this ROM only:\n' + VERSIONS.map((x) => `  ${x.label}: SHA-1 ${x.sha1} (${x.file})`).join('\n');
    return { version: null, sha1, msg };
}

async function extractAssets(romPath, options = {}) {
    // Set default options
    const extractOptions = {
        outputDir: options.outputDir || path.join(__dirname, '..', 'Extracted'),
        verbose: options.verbose || false
    };
    
    try {
        const romData = await fs.readFile(romPath);
        const { version, sha1, msg } = detectVersion(romData);
        if (!version) {
            console.error(msg + '\nAborting extraction.');
            process.exitCode = 1;
            return;
        }
        console.log(`ROM: ${version.label}`);

        // Create base Extracted directory
        const baseDir = extractOptions.outputDir;
        await fs.mkdir(baseDir, { recursive: true });
        // The completion marker is written last; remove it first so a broken run leaves none.
        const markerPath = path.join(baseDir, '.extract-complete.json');
        await fs.rm(markerPath, { force: true });
        const written = [];

        // Extract each asset
        for (const asset of assets) {
            // Create output directory
            const outputDir = path.join(baseDir, asset.folder);
            await fs.mkdir(outputDir, { recursive: true });

            // Extract data
            const assetData = romData.slice(asset.start, asset.end);

            // Write to file
            const outputPath = path.join(outputDir, asset.name);
            await fs.writeFile(outputPath, assetData);
            written.push({ path: path.posix.join(asset.folder.replace(/\\/g, '/'), asset.name), size: assetData.length });
            
            if (extractOptions.verbose) {
                console.log(`Extracted ${asset.name} (${assetData.length} bytes) from offset 0x${asset.start.toString(16)} to 0x${asset.end.toString(16)}`);
                console.log(`Saved to ${outputPath}`);
            } else {
                console.log(`Extracted ${asset.name} to ${outputPath}`);
            }
        }

        // Completion marker for tools/prebuild.js: ROM, extractor version and every file written.
        const extractorSha1 = crypto.createHash('sha1').update(await fs.readFile(__filename)).digest('hex');
        await fs.writeFile(markerPath, JSON.stringify({ rom: version.id, romSha1: sha1, extractor: path.basename(__filename),
            extractorSha1, files: written }, null, 1) + '\n');
        console.log('Extraction completed successfully.');
        console.log(`Extracted ${assets.length} assets from NHL 92 ROM.`);
    } catch (error) {
        console.error(`Error during extraction: ${error.message}`);
        process.exitCode = 1;
    }
}

// Parse command line arguments
function parseArgs() {
    const args = process.argv.slice(2);
    const options = {
        romFile: null,
        outputDir: path.join(__dirname, '..', 'Extracted'),
        verbose: false
    };

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        
        if (arg === '-h' || arg === '--help') {
            displayHelp();
            process.exit(0);
        } else if (arg === '-v' || arg === '--verbose') {
            options.verbose = true;
        } else if (arg === '-o' || arg === '--output') {
            if (i + 1 < args.length) {
                options.outputDir = args[++i];
            } else {
                console.error('Error: Output directory not specified');
                displayHelp();
                process.exit(1);
            }
        } else if (!options.romFile) {
            options.romFile = arg;
        }
    }

    return options;
}

// Display help information
function displayHelp() {
    console.log(`
NHL 92 Asset Extractor
======================

This script extracts assets from NHL Hockey (1991/1992) ROM files.

Usage: node tools/extractAssets92.js [options] <rom_file_path>

Options:
  -h, --help              Display this help message
  -v, --verbose           Display detailed extraction information
  -o, --output <dir>      Specify output directory (default: Extracted/ in the repo folder)

Notes:
  - This script extracts all known assets from the NHL 92 ROM
  - the ROM SHA-1 is verified to ensure correct ROM is used

Examples:
  node tools/extractAssets92.js nhl92retail.bin
  node tools/extractAssets92.js --verbose --output NHL92Assets nhl92retail.bin
    `);
}

// Main execution
const options = parseArgs();

if (!options.romFile) {
    console.error('Error: ROM file path not provided');
    displayHelp();
    process.exit(1);
}

console.log(`Extracting assets from: ${options.romFile}`);
console.log(`Output directory: ${options.outputDir}`);
if (options.verbose) {
    console.log('Verbose mode enabled');
}

extractAssets(options.romFile, {
    outputDir: options.outputDir,
    verbose: options.verbose
});