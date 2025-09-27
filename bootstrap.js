#!/usr/bin/env node

/**
 * Cappuccino Bootstrap Script
 *
 * This script manages the installation and configuration of the Cappuccino framework
 * development environment. It handles symlink creation for tools, builds the framework,
 * and verifies system requirements.
 *
 * @author David Richardson
 * @version 1.0.0
 * Copyright (c) 2025 cappuccino.dev. All rights reserved.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// MARK: - Configuration

/**
 * Project configuration constants
 */
const PROJECT_ROOT = process.cwd();
const INSTALL_DIR = '/usr/local/bin';
const TOOL_PATHS = [
    'dist/cappuccino/bin',
    'dist/objective-j/bin'
];

/**
 * ANSI color codes for console output
 */
const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    reset: '\x1b[0m'
};

// MARK: - Utility Functions

/**
 * Logs a message to the console with optional color formatting
 *
 * @param {string} message - The message to log
 * @param {string} color - The color name from the colors object
 */
function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

/**
 * Checks if the current process has write permissions to the install directory
 *
 * @returns {boolean} True if write permissions are available
 */
function checkPermissions() {
    try {
        fs.accessSync(INSTALL_DIR, fs.constants.W_OK);
        return true;
    } catch (err) {
        return false;
    }
}

// MARK: - Executable Discovery

/**
 * Searches for executable files in the configured tool paths
 *
 * @returns {Array<Object>} Array of executable objects with name, source, and target paths
 */
function findExecutables() {
    const executables = [];

    for (const toolPath of TOOL_PATHS) {
        const fullPath = path.join(PROJECT_ROOT, toolPath);

        if (!fs.existsSync(fullPath)) {
            log(`Warning: ${toolPath} not found, skipping`, 'yellow');
            continue;
        }

        try {
            const files = fs.readdirSync(fullPath);

            for (const file of files) {
                const filePath = path.join(fullPath, file);
                const stat = fs.statSync(filePath);

                // Check if file is executable (basic check)
                if (stat.isFile() && (stat.mode & parseInt('111', 8))) {
                    executables.push({
                        name: file,
                        source: filePath,
                        target: path.join(INSTALL_DIR, file)
                    });
                }
            }
        } catch (err) {
            log(`Error reading ${fullPath}: ${err.message}`, 'red');
        }
    }

    return executables;
}

function symlinkNodeModulesIfExists(targetDir) {
    const nodeModulesSource = path.join(process.cwd(), 'node_modules');
    const nodeModulesTarget = path.join(targetDir, 'node_modules');

    // Check if source node_modules exists
    if (!fs.existsSync(nodeModulesSource)) {
        console.log('node_modules not found in source root, skipping symlink');
        return false;
    }

    // Check if target already exists
    if (fs.existsSync(nodeModulesTarget)) {
        // Check if it's already a symlink to our source
        if (fs.lstatSync(nodeModulesTarget).isSymbolicLink()) {
            const linkTarget = fs.readlinkSync(nodeModulesTarget);
            if (path.resolve(linkTarget) === path.resolve(nodeModulesSource)) {
                console.log('node_modules symlink already exists and points to correct location');
                return true;
            }
        }
        console.log('node_modules already exists at target, skipping');
        return false;
    }

    try {
        fs.symlinkSync(nodeModulesSource, nodeModulesTarget);
        console.log(`Created node_modules symlink: ${nodeModulesTarget} -> ${nodeModulesSource}`);
        return true;
    } catch (error) {
        console.error(`Failed to create node_modules symlink: ${error.message}`);
        return false;
    }
}

// MARK: - System Requirements

/**
 * Checks for Python 2 installation required for XcodeCapp tool
 *
 * @returns {Object} Object with found boolean and version/reason information
 */
function checkPython2() {
    const pythonPath = '/usr/bin/python';

    if (fs.existsSync(pythonPath)) {
        try {
            const version = execSync(`"${pythonPath}" --version`, { encoding: 'utf8', stderr: 'stdout' });
            if (version.includes('Python 2.')) {
                return { found: true, version: version.trim() };
            } else {
                return { found: false, reason: `Found ${version.trim()} but need Python 2.x` };
            }
        } catch (err) {
            return { found: false, reason: 'Python executable exists but version check failed' };
        }
    }

    return { found: false, reason: 'No python found at /usr/bin/python' };
}

// MARK: - Build Operations

/**
 * Runs the Jake build process to compile Cappuccino frameworks
 *
 * @returns {boolean} True if build succeeded, false otherwise
 */
function runJakeBuild() {
    const jakePath = path.join(PROJECT_ROOT, 'dist', 'cappuccino', 'bin', 'jake');

    if (!fs.existsSync(jakePath)) {
        log('Error: jake not found in dist/cappuccino/bin/', 'red');
        log('Make sure the project has been built at least once', 'yellow');
        return false;
    }

    try {
        log('Building Cappuccino frameworks...', 'blue');
        execSync(`"${jakePath}" build`, {
            stdio: 'inherit',
            cwd: PROJECT_ROOT
        });
        log('Build completed successfully', 'green');
        return true;
    } catch (err) {
        log(`Build failed: ${err.message}`, 'red');
        return false;
    }
}

// MARK: - Symlink Management

/**
 * Creates symbolic links for all Cappuccino tools in the system PATH
 *
 * @returns {boolean} True if installation succeeded
 */
function installSymlinks() {
    log('Installing Cappuccino tool symlinks...', 'blue');

    if (!checkPermissions()) {
        log(`Error: No write permission to ${INSTALL_DIR}`, 'red');
        log('Try running with sudo: sudo node bootstrap.js install', 'yellow');
        return false;
    }

    const executables = findExecutables();

    if (executables.length === 0) {
        log('No executables found to install', 'yellow');
        log('Make sure you have built the project first with: jake dist', 'yellow');
        return false;
    }

    let installed = 0;
    let skipped = 0;

    for (const exe of executables) {
        try {
            // Check if target already exists
            if (fs.existsSync(exe.target)) {
                try {
                    const linkTarget = fs.readlinkSync(exe.target);
                    if (linkTarget === exe.source) {
                        log(`  ${exe.name} - already installed correctly`, 'green');
                        skipped++;
                        continue;
                    } else {
                        log(`  ${exe.name} - exists but points to different location`, 'yellow');
                        log(`    Current: ${linkTarget}`, 'yellow');
                        log(`    Expected: ${exe.source}`, 'yellow');

                        // Remove existing and continue to create new one
                        fs.unlinkSync(exe.target);
                    }
                } catch (err) {
                    // Not a symlink, remove it
                    log(`  ${exe.name} - removing existing file`, 'yellow');
                    fs.unlinkSync(exe.target);
                }
            }

            // Create symlink
            fs.symlinkSync(exe.source, exe.target);
            log(`  ${exe.name} - installed`, 'green');
            installed++;

        } catch (err) {
            log(`  ${exe.name} - failed: ${err.message}`, 'red');
        }
    }

    // Add link to node_modules


    log(`\nSymlink installation complete: ${installed} installed, ${skipped} already present`, 'blue');

    if (installed > 0) {
        log('\nTools are now available in your PATH:', 'green');
        executables.forEach(exe => {
            if (fs.existsSync(exe.target)) {
                log(`  ${exe.name}`, 'green');
            }
        });
    }

    symlinkNodeModulesIfExists('/usr/local/bin');

    return true;
}

/**
 * Removes symbolic links for Cappuccino tools from the system PATH
 *
 * @returns {boolean} True if removal succeeded
 */
function removeSymlinks() {
    log('Removing Cappuccino tool symlinks...', 'blue');

    if (!checkPermissions()) {
        log(`Error: No write permission to ${INSTALL_DIR}`, 'red');
        log('Try running with sudo: sudo node bootstrap.js remove', 'yellow');
        return false;
    }

    const executables = findExecutables();
    let removed = 0;
    let notFound = 0;

    for (const exe of executables) {
        try {
            if (!fs.existsSync(exe.target)) {
                log(`  ${exe.name} - not installed`, 'yellow');
                notFound++;
                continue;
            }

            // Check if it's actually our symlink
            try {
                const linkTarget = fs.readlinkSync(exe.target);
                if (linkTarget !== exe.source) {
                    log(`  ${exe.name} - not our symlink (points to ${linkTarget})`, 'yellow');
                    continue;
                }
            } catch (err) {
                log(`  ${exe.name} - not a symlink, skipping`, 'yellow');
                continue;
            }

            fs.unlinkSync(exe.target);
            log(`  ${exe.name} - removed`, 'green');
            removed++;

        } catch (err) {
            log(`  ${exe.name} - failed to remove: ${err.message}`, 'red');
        }
    }

    log(`\nRemoval complete: ${removed} removed, ${notFound} not found`, 'blue');
    return true;
}

/**
 * Displays the current status of all Cappuccino tool symlinks
 */
function listSymlinks() {
    log('Cappuccino tool symlinks status:', 'blue');

    const executables = findExecutables();

    if (executables.length === 0) {
        log('No executables found in dist directories', 'yellow');
        return;
    }

    for (const exe of executables) {
        if (!fs.existsSync(exe.target)) {
            log(`  ${exe.name} - not installed`, 'red');
            continue;
        }

        try {
            const linkTarget = fs.readlinkSync(exe.target);
            if (linkTarget === exe.source) {
                log(`  ${exe.name} - installed correctly`, 'green');
            } else {
                log(`  ${exe.name} - installed but points elsewhere: ${linkTarget}`, 'yellow');
            }
        } catch (err) {
            log(`  ${exe.name} - exists but not a symlink`, 'yellow');
        }
    }
}

// MARK: - Complete Installation

/**
 * Performs a complete Cappuccino installation including symlinks, build, and verification
 *
 * @returns {boolean} True if complete installation succeeded
 */
function completeInstall() {
    log('Starting complete Cappuccino installation...', 'blue');
    log('=====================================', 'blue');

    // Step 1: Check system requirements
    log('\n1. Checking system requirements...', 'blue');
    const python2Status = checkPython2();

    if (python2Status.found) {
        log(`  Python 2: ${python2Status.version}`, 'green');
    } else {
        log(`  Python 2: ${python2Status.reason}`, 'yellow');
        log('  Note: Python 2 is optional but required for XcodeCapp tool', 'yellow');
    }

    // Step 2: Install symlinks
    log('\n2. Installing tool symlinks...', 'blue');
    const symlinkSuccess = installSymlinks();

    if (!symlinkSuccess) {
        log('\nInstallation failed at symlink creation step', 'red');
        return false;
    }

    // Step 3: Build frameworks
    log('\n3. Building Cappuccino frameworks...', 'blue');
    const buildSuccess = runJakeBuild();

    if (!buildSuccess) {
        log('\nWarning: Framework build failed, but tools are installed', 'yellow');
        log('You may need to run the build manually later', 'yellow');
    }

    // Step 4: Verify installation
    log('\n4. Verifying installation...', 'blue');
    listSymlinks();

    log('\n=====================================', 'blue');
    if (buildSuccess) {
        log('Complete installation finished successfully!', 'green');
        log('\nYou can now use Cappuccino development tools.', 'green');
        log('Try running: cappuccino-config --help', 'green');
    } else {
        log('Installation completed with warnings', 'yellow');
        log('Tools are installed but framework build failed', 'yellow');
    }

    return true;
}

// MARK: - Help and Usage

/**
 * Displays usage information for the script
 */
function showUsage() {
    log('Cappuccino Bootstrap Script', 'blue');
    log('===========================', 'blue');
    log('');
    log('Usage: node bootstrap.js <command>', 'blue');
    log('');
    log('Commands:');
    log('  setup     - Complete installation (symlinks + build + verification)');
    log('  install   - Create symlinks to /usr/local/bin only');
    log('  build     - Build Cappuccino frameworks only');
    log('  remove    - Remove symlinks from /usr/local/bin');
    log('  list      - Show current symlink status');
    log('  help      - Show this help message');
    log('');
    log('Examples:');
    log('  sudo node bootstrap.js setup     # Complete installation');
    log('  node bootstrap.js list          # Check current status');
    log('  sudo node bootstrap.js remove   # Uninstall symlinks');
    log('');
    log('Note: You may need to run with sudo for /usr/local/bin access');
}

// MARK: - Main Execution

/**
 * Main entry point for the script
 */
function main() {
    const command = process.argv[2];

    switch (command) {
        case 'setup':
            completeInstall();
            break;
        case 'install':
            installSymlinks();
            break;
        case 'build':
            runJakeBuild();
            break;
        case 'remove':
            removeSymlinks();
            break;
        case 'list':
            listSymlinks();
            break;
        case 'help':
        case '--help':
        case '-h':
            showUsage();
            break;
        default:
            log('Error: Unknown command or no command provided', 'red');
            log('');
            showUsage();
            process.exit(1);
    }
}

// MARK: - Error Handling

/**
 * Global error handler for uncaught exceptions
 */
process.on('uncaughtException', (err) => {
    log(`Unexpected error: ${err.message}`, 'red');
    log('Stack trace:', 'red');
    log(err.stack, 'red');
    process.exit(1);
});

// MARK: - Script Entry Point

if (require.main === module) {
    main();
}
