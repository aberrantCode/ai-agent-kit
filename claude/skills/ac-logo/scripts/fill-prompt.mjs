#!/usr/bin/env node
// fill-prompt.mjs — fill the canonical AC logo prompt with interview values.
//
// The canonical prompt lives in AC_DESIGN's docs/logo-design-system.md, under
// "### The prompt" (the first ```text fenced block). This script extracts that
// block verbatim and only substitutes the three placeholders + applies the
// documented light-theme palette swaps, so the design-system doc stays the
// single source of truth. Used by /generate-logo's fallback path (icon art the
// model must render).
//
// The AC_DESIGN repo is resolved from the AC_DESIGN_ROOT environment variable,
// falling back to C:\development\ac_design — never relative to this script's
// install location, which may be anywhere.
//
// Usage:
//   node fill-prompt.mjs --concept "<core concept>" \
//                        --primary "<top line word>" \
//                        --secondary "<bottom line word>" \
//                        --theme dark|light \
//                        [--template <path to alternate prompt doc>]
//
// Prints the finished, copy-ready prompt to stdout. Writes no files.

import { readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';

import { acDesignRoot } from './ac-design-root.mjs';

// --- parse "--key value" args (values may contain spaces) ----------------
function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const tok = argv[i];
    if (tok.startsWith('--')) {
      const key = tok.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) {
        out[key] = true; // bare flag
      } else {
        out[key] = next;
        i += 1;
      }
    }
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));

const concept = (args.concept || '').trim();
const primary = (args.primary || '').trim();
const secondary = (args.secondary || '').trim();
const theme = String(args.theme || 'dark').trim().toLowerCase();

const missing = [];
if (!concept) missing.push('--concept');
if (!primary) missing.push('--primary');
if (!secondary) missing.push('--secondary');
if (missing.length) {
  console.error(`fill-prompt: missing required arg(s): ${missing.join(', ')}`);
  console.error(
    'usage: node fill-prompt.mjs --concept "..." --primary "..." --secondary "..." --theme dark|light',
  );
  process.exit(2);
}
if (theme !== 'dark' && theme !== 'light') {
  console.error(`fill-prompt: --theme must be "dark" or "light" (got "${theme}")`);
  process.exit(2);
}

// --- locate the canonical doc in the AC_DESIGN repo ------------------------
function findDoc() {
  if (args.template) return resolve(String(args.template));
  return join(acDesignRoot(), 'docs', 'logo-design-system.md');
}

const docPath = findDoc();
let doc;
try {
  doc = readFileSync(docPath, 'utf8');
} catch (err) {
  console.error(`fill-prompt: cannot read canonical prompt at ${docPath}`);
  console.error(`  ${err.message}`);
  console.error('  set AC_DESIGN_ROOT to your ac_design checkout, or pass --template <path>');
  process.exit(1);
}

// --- extract the first ```text fenced block (the dark/primary prompt) ------
const blockMatch = doc.match(/```text\r?\n([\s\S]*?)```/);
if (!blockMatch) {
  console.error(
    `fill-prompt: no \`\`\`text prompt block found in ${docPath} — has the doc format changed?`,
  );
  process.exit(1);
}
let prompt = blockMatch[1].replace(/\s+$/, '');

// --- substitute the three placeholders ------------------------------------
// The concept placeholder carries an inline "— e.g. ..." hint; match the whole bracket.
prompt = prompt.replace(/\[INSERT CORE CONCEPT[^\]]*\]/g, concept);
prompt = prompt.split('[PRIMARY WORD]').join(primary);
prompt = prompt.split('[SECONDARY WORD]').join(secondary);

// --- light-theme variant: apply the palette swaps documented in the .md ----
// "One identity, two themes." Light = silkscreen board with deeper phosphor.
// Hexes match docs/logo-design-system.md#light--dark-variants exactly.
if (theme === 'light') {
  prompt = prompt
    .split('#5cf0a3').join('#1c7049')                 // phosphor green -> deeper trace
    .split('#2f9b6a').join('#1c7049')                 // phosphor mid  -> deeper trace
    .split('#f2f5f3').join('#22332b')                 // off-white text -> dark green-black
    .split('#050505 to #121212').join('#e7ece9')      // substrate -> light silkscreen board
    .split('#050505–#121212').join('#e7ece9')    // (en-dash form, if present)
    .split('#050505').join('#e7ece9')                 // any remaining substrate ref
    .split('near-black').join('light silkscreen');    // keep prose coherent with the new fill
}

// --- guard: surface any placeholder we failed to fill ----------------------
const leftover = prompt.match(/\[[^\]]*\]/g);
if (leftover) {
  console.error(`fill-prompt: warning — unfilled placeholder(s): ${leftover.join(', ')}`);
}

process.stdout.write(`${prompt}\n`);
