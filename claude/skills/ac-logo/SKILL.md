---
name: ac-logo
category: UI & Design
description: >
  Full lifecycle for AC "PCB phosphor console" brand logos in any repository — finding
  existing logo assets and judging them against the brand checklist, generating a new
  on-brand badge, reskinning an off-brand logo into the house style, and archiving a
  repo's logo set back to the AC_DESIGN gallery. Triggers on "/find-logo",
  "/generate-logo", "/reskin-logo", "/archive-logo", and phrasings like "make a logo for
  this repo", "is this logo on-brand", "rebrand this icon to the AC style", "convert
  this logo to the phosphor style", or "save this logo to the design gallery". All brand
  requirements are read at runtime from the AC_DESIGN repository — never copied.
status: active
version: 1.0.0
---

# AC Logo

Operation-neutral bundle for AC brand logos. Four thin commands map to the four
operations below; this skill executes them against the **current repository**, reading
every brand requirement from the AC_DESIGN repo at runtime.

---

## AC_DESIGN resolution — applies to EVERY operation

Resolve the AC_DESIGN repository root once per invocation:

1. `AC_DESIGN_ROOT` environment variable, if set.
2. Fallback: `C:\development\ac_design`.

If the resolved directory does not contain `docs/logo-design-system.md`, stop and report
the problem — do not guess or substitute cached knowledge.

**Brand requirements live there, never here.** Read these at runtime:

| Requirement | Path under `AC_DESIGN_ROOT` |
| --- | --- |
| Canonical design system (geometry, palette, wordmark rules, brand checklist, canonical text-to-image prompt) | `docs/logo-design-system.md` |
| Shared theme tokens (OKLCH hue-152 palette) | `artifacts/styles/shared-theme.css` |
| Sibling badges — structural references | `artifacts/logos/` (gold standard: `sni-console.svg`) |
| Deterministic frame generator (use when present) | `.claude/skills/generate-logo/scripts/build-logo.mjs` |
| Reusable icon fragments | `.claude/skills/generate-logo/icons/` |

The bundle's own scripts under `scripts/` are invoked via **this skill's directory**
(the directory containing this SKILL.md) — never via paths relative to the current
repo's root, since the skill may be installed anywhere.

## Interaction contract

Whenever a required input is missing or a decision is needed (concept, product name,
theme restriction, overwrite confirmation, icon choice), ask via **`AskUserQuestion`** —
one batched call where possible, prefilled with any values the user already supplied.
Never ask free-text questions in plain output.

---

## Operation: find (`/find-logo`)

Scan the current repository for logo assets and report their on-brand status.

1. Glob for candidate assets: `**/*.{svg,png,jpg,jpeg,ico}` whose path or name suggests
   branding — `logo`, `badge`, `icon`, `favicon`, `brand`, or living under `assets/`,
   `public/`, `static/`, `artifacts/logos/`, `.github/`. Skip `node_modules/`, build
   output, and third-party vendored assets.
2. Read `AC_DESIGN_ROOT/docs/logo-design-system.md` and evaluate each SVG candidate
   against the **Brand checklist** section (geometry, double-pinstripe border, icon
   zone, two-line wordmark, palette-only colours). Rasters can only be judged on
   palette and composition — say so.
3. Report a table: path, format, theme (dark/light/unknown), on-brand verdict with the
   specific checklist items that fail, and whether the 8-file variant set
   (SVG/PNG/JPG/ICO × dark/light) is complete.
4. If assets fail the checklist, offer next steps via `AskUserQuestion`: reskin
   (`/reskin-logo`), regenerate (`/generate-logo`), or leave as-is.

## Operation: generate (`/generate-logo`)

Produce a new, conforming badge for the current repo (or an explicitly named product).

1. **Interview.** Collect via a single `AskUserQuestion` batch — prefilling anything the
   user already supplied and offering README-derived recommendations as the first
   option: **Concept** (one literal, schematic object), **Product name** (→ tag/subtag
   per the doc's overflow rules), **Theme scope** (both dark+light is the default).
2. **Author the dark SVG.** Read the design-system doc first; the badge must be a
   structural sibling of `AC_DESIGN_ROOT/artifacts/logos/sni-console.svg`.
   - Preferred: if `AC_DESIGN_ROOT/.claude/skills/generate-logo/scripts/build-logo.mjs`
     exists, run it (`--product "<PRODUCT>" --theme dark --icon <fragment.svg> --out
     <dark.svg>`) so frame + wordmark are deterministic, authoring only the icon
     fragment (flat schematic vector, palette `#5cf0a3`/`#2f9b6a`, no glow filter —
     the generator adds it).
   - Fallback: author the full 512×512 badge by hand strictly per the doc's canonical
     geometry, wordmark, and palette tables.
   - For a concept too illustrative to author as vector, emit the canonical
     text-to-image prompt with `scripts/fill-prompt.mjs` (see below) and hand it to the
     user; the production icon must still land as flat vector.
3. **Verify** the authored SVG against the doc's Brand checklist before proceeding.
4. **Variants.** Run `scripts/make-variants.mjs` on the dark SVG to emit the 8-file set
   (see Pipeline below) into the repo's conventional asset directory (`assets/` unless
   the repo already keeps brand assets elsewhere).
5. Present the written set and the checklist confirmation.

```bash
# canonical text-to-image prompt (fallback path only)
node "<skill-dir>/scripts/fill-prompt.mjs" \
  --concept "<core concept>" --primary "<tag>" --secondary "<subtag>" --theme dark|light
```

## Operation: reskin (`/reskin-logo`)

**Self-contained** — do not delegate to any other skill (in particular, do not invoke
`logo-restylizer`).

1. Locate the current repo's existing logo (run the *find* scan if the user didn't name
   a file). If several candidates exist, choose via `AskUserQuestion`.
2. Read the existing logo and extract its **subject** — what the mark depicts, not its
   current style.
3. Redraw that subject as an on-brand **dark SVG** strictly per
   `AC_DESIGN_ROOT/docs/logo-design-system.md`: 512×512 disc, double-pinstripe border,
   schematic phosphor icon in the icon zone, two-line wordmark (product name derived
   from the repo; confirm via `AskUserQuestion` if ambiguous).
4. Verify against the Brand checklist, then run `scripts/make-variants.mjs` to emit the
   8-file set alongside (or replacing, with `AskUserQuestion` confirmation) the old
   assets.

## Operation: archive (`/archive-logo`)

Copy the current repo's logo set into the AC_DESIGN gallery.

1. Identify the repo's logo set (dark SVG at minimum; take the full 8-file set when
   present). Derive the gallery name: **kebab-case** of the repo/product name (e.g.
   `ai-tag-browser`). Confirm the name via `AskUserQuestion` if it isn't obvious.
2. Destination: `AC_DESIGN_ROOT/artifacts/logos/<name>.<ext>` and
   `<name>-light.<ext>`.
3. If any destination file already exists, ask before overwriting via
   `AskUserQuestion` (overwrite / skip existing / abort). Never overwrite silently.
4. Copy, then report exactly what landed in the gallery.

---

## Pipeline: `scripts/make-variants.mjs`

Given an **authored dark SVG**, emits the full 8-file deliverable set using installed
ImageMagick (`magick`):

| File | Notes |
| --- | --- |
| `<name>.svg` | the authored dark badge (copied to the output dir if needed) |
| `<name>-light.svg` | deterministic token swap per the doc's light-theme rules: `#5cf0a3`→`#1c7049`, `#2f9b6a`→`#1c7049`, `#f2f5f3`→`#22332b`, substrate (`#050505`/`#121212`)→`#e7ece9` |
| `<name>.png` / `<name>-light.png` | 1024², transparent background |
| `<name>.jpg` / `<name>-light.jpg` | flattened onto the matte substrate — dark `#050505`, light `#e7ece9` |
| `<name>.ico` / `<name>-light.ico` | multi-size 16/32/48/256 |

```bash
node "<skill-dir>/scripts/make-variants.mjs" --svg <dark.svg> [--out-dir <dir>] [--name <base>]
```

The script is theme-token-driven and writes nothing outside `--out-dir` (default: the
input SVG's directory).

## Guardrails

- Never hand-edit frame/wordmark geometry away from the doc's constants; never
  introduce colours outside the doc's palette table.
- Dark is primary — always author dark first; light is derived, never hand-tuned.
- Verify every produced badge against the doc's **Brand checklist** before declaring it
  done.
- The design-system doc in AC_DESIGN is the single source of truth; if this skill and
  the doc disagree, the doc wins.
