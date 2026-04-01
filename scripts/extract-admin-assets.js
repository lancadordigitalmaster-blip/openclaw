#!/usr/bin/env node
// Extract inline CSS and JS from admin.html into separate files
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');

const root = join(__dirname, '..');
const src = readFileSync(join(root, 'public/admin.html'), 'utf-8');

// Extract CSS
const styleMatch = src.match(/<style>([\s\S]*?)<\/style>/);
if (styleMatch) {
  writeFileSync(join(root, 'public/admin.css'), styleMatch[1].trim() + '\n');
  console.log(`admin.css: ${styleMatch[1].length} bytes`);
}

// Extract JS (last <script> block)
const scriptMatches = [...src.matchAll(/<script>([\s\S]*?)<\/script>/g)];
if (scriptMatches.length > 0) {
  const lastScript = scriptMatches[scriptMatches.length - 1][1];
  writeFileSync(join(root, 'public/admin.js'), lastScript.trim() + '\n');
  console.log(`admin.js: ${lastScript.length} bytes`);
}

// Replace inline with external references
let html = src.replace(/<style>[\s\S]*?<\/style>/, '<link rel="stylesheet" href="/admin.css">');

// Replace the last script block only
const lastIdx = html.lastIndexOf('<script>');
const lastEnd = html.indexOf('</script>', lastIdx);
if (lastIdx !== -1 && lastEnd !== -1) {
  html = html.slice(0, lastIdx) + '<script src="/admin.js"></script>' + html.slice(lastEnd + '</script>'.length);
}

writeFileSync(join(root, 'public/admin.html'), html);
console.log(`admin.html: ${html.length} bytes (was ${src.length})`);
