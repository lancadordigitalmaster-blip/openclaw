#!/usr/bin/env node
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');
const { generateHTML } = require('../../../_lib/builder');

const data = JSON.parse(readFileSync(join(__dirname, 'victor-input.json'), 'utf-8'));
const template = readFileSync(join(__dirname, '../../../_lib/template.html'), 'utf-8');
const html = generateHTML(data, template);

const outPath = join(__dirname, 'proposta-victor.html');
writeFileSync(outPath, html, 'utf-8');
console.log('HTML gerado:', outPath);
console.log('Tamanho:', Math.round(html.length / 1024), 'KB');
