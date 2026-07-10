#!/usr/bin/env node
// make-variants.mjs — expand an authored dark AC badge SVG into the full
// 8-file deliverable set: SVG / PNG / JPG / ICO in dark and light themes.
//
//   <name>.svg          the authored dark badge (copied into --out-dir)
//   <name>-light.svg    deterministic light-theme token swap (no redraw)
//   <name>.png          1024x1024, transparent
//   <name>-light.png    1024x1024, transparent
//   <name>.jpg          flattened onto the dark matte substrate  #050505
//   <name>-light.jpg    flattened onto the light matte substrate #e7ece9
//   <name>.ico          multi-size 16/32/48/256
//   <name>-light.ico    multi-size 16/32/48/256
//
// Light-theme swaps follow AC_DESIGN docs/logo-design-system.md
// ("Light & dark variants"): geometry and type never change, only colour.
// Rasters are produced with installed ImageMagick (`magick`).
//
// Usage:
//   node make-variants.mjs --svg <dark.svg> [--out-dir <dir>] [--name <base>]

import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const PNG_SIZE = 1024;
const ICO_SIZES = '256,48,32,16';
const SUBSTRATE = { dark: '#050505', light: '#e7ece9' };

// The documented light-theme palette swap — applied to the SVG text verbatim
// so the light variant is deterministic, never hand-tuned.
const LIGHT_SWAPS = [
  ['#5cf0a3', '#1c7049'], // phosphor highlight -> deeper trace
  ['#2f9b6a', '#1c7049'], // phosphor mid       -> deeper trace
  ['#f2f5f3', '#22332b'], // off-white tag text -> dark green-black
  ['#121212', '#e7ece9'], // substrate gradient stop -> light silkscreen
  ['#050505', '#e7ece9'], // substrate gradient stop -> light silkscreen
];

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const tok = argv[i];
    if (tok.startsWith('--')) {
      const key = tok.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) {
        out[key] = true;
      } else {
        out[key] = next;
        i += 1;
      }
    }
  }
  return out;
}

function fail(msg) {
  console.error(`make-variants: ${msg}`);
  process.exit(1);
}

function run(cmd, cmdArgs) {
  const res = spawnSync(cmd, cmdArgs, { encoding: 'utf8' });
  if (res.error) fail(`cannot run ${cmd}: ${res.error.message}`);
  if (res.status !== 0) {
    fail(`${cmd} ${cmdArgs.join(' ')}\n  exited ${res.status}: ${res.stderr || res.stdout}`);
  }
  return res.stdout;
}

const args = parseArgs(process.argv.slice(2));
if (!args.svg || args.svg === true) {
  console.error('usage: node make-variants.mjs --svg <dark.svg> [--out-dir <dir>] [--name <base>]');
  process.exit(2);
}

const srcPath = resolve(String(args.svg));
if (!existsSync(srcPath)) fail(`input SVG not found: ${srcPath}`);

const outDir = resolve(String(args['out-dir'] || dirname(srcPath)));
const name = String(args.name || basename(srcPath).replace(/\.svg$/i, '').replace(/-light$/i, ''));
mkdirSync(outDir, { recursive: true });

const magickCheck = spawnSync('magick', ['-version'], { encoding: 'utf8' });
if (magickCheck.error) fail('ImageMagick (`magick`) not found on PATH — install it first.');

// --- 1) dark + light SVGs ---------------------------------------------------
const darkSvgText = readFileSync(srcPath, 'utf8');
if (!/#5cf0a3/i.test(darkSvgText)) {
  console.error(
    'make-variants: warning — input has no #5cf0a3 phosphor stroke; is this really a dark AC badge?',
  );
}

const lightSvgText = LIGHT_SWAPS.reduce(
  (text, [from, to]) => text.split(from).join(to).split(from.toUpperCase()).join(to),
  darkSvgText,
);

const paths = (theme) => {
  const base = theme === 'dark' ? name : `${name}-light`;
  return {
    svg: join(outDir, `${base}.svg`),
    png: join(outDir, `${base}.png`),
    jpg: join(outDir, `${base}.jpg`),
    ico: join(outDir, `${base}.ico`),
  };
};
const dark = paths('dark');
const light = paths('light');

if (resolve(dark.svg) !== srcPath) copyFileSync(srcPath, dark.svg);
writeFileSync(light.svg, lightSvgText, 'utf8');

// --- 2) rasters per theme ----------------------------------------------------
// -density 144 renders the 512-unit viewBox at ~1024px before the exact resize,
// so strokes stay crisp instead of being upscaled.
function rasterize(theme, p) {
  run('magick', [
    '-background', 'none', '-density', '144', p.svg,
    '-resize', `${PNG_SIZE}x${PNG_SIZE}`, p.png,
  ]);
  run('magick', [
    '-background', SUBSTRATE[theme], '-density', '144', p.svg,
    '-resize', `${PNG_SIZE}x${PNG_SIZE}`, '-flatten', p.jpg,
  ]);
  run('magick', [p.png, '-define', `icon:auto-resize=${ICO_SIZES}`, p.ico]);
}

rasterize('dark', dark);
rasterize('light', light);

// --- 3) report ---------------------------------------------------------------
const emitted = [dark, light].flatMap((p) => [p.svg, p.png, p.jpg, p.ico]);
const missingOut = emitted.filter((p) => !existsSync(p));
if (missingOut.length) fail(`expected outputs missing: ${missingOut.join(', ')}`);

console.log(`make-variants: wrote ${emitted.length} files to ${outDir}`);
for (const p of emitted) console.log(`  ${basename(p)}`);
