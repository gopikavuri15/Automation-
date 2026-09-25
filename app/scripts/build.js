const fs = require('node:fs');
const path = require('node:path');

const appRoot = path.resolve(__dirname, '..');
const outputDir = path.join(appRoot, 'dist');

fs.rmSync(outputDir, { recursive: true, force: true });
fs.mkdirSync(path.join(outputDir, 'public'), { recursive: true });
fs.copyFileSync(path.join(appRoot, 'src', 'server.js'), path.join(outputDir, 'server.js'));
fs.copyFileSync(path.join(appRoot, 'public', 'index.html'), path.join(outputDir, 'public', 'index.html'));
console.log(`Built application into ${outputDir}`);