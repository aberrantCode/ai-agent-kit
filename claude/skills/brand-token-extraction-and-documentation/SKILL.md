---
name: brand-token-extraction-and-documentation
description: Use when reskinning an app with a real brand's visual identity — extract the actual palette from a live site's raw CSS (not markdown), recreate logo/icon assets programmatically with documented extraction rationale, and codify everything as versioned, named design tokens rather than one-off hardcoded values.
status: active
version: 2026-07-05
---

# Brand Token Extraction and Documentation

## When to use

You need to reskin or extend an app to match a real brand's colors, logo, and type scale — either pulling from a live website you don't control, or from a client-provided logo/asset pack. Also use when a design system needs new tokens derived from an existing brand baseline (e.g., adding a presentation theme to an established product).

## Method

### Extracting from a live site
1. **Fetch raw HTML/CSS, never markdown-converted content** — markdown conversion strips all styling, which is exactly the data you need.
2. Use `curl` to fetch the raw HTML, `grep` for `<link>` tags pointing to stylesheets, then fetch each linked CSS file.
3. **Rank colors by occurrence count** across the combined stylesheet to find the *real* palette — don't just take the first hex values you see.
4. **Skip known theme-framework defaults** (e.g., Divi's `#2ea3f2`) that show up frequently but aren't actually brand colors — they're artifacts of the page-builder, not intentional choices.
5. For brand imagery (logo, icon mark) where the official source file isn't available, **inspect the actual rendered SVG/PNG** to understand its visual construction (two-tone split, italic wordmark, etc.) and **recreate it programmatically** rather than approximating by eye.

### Capturing and documenting tokens
6. **Record exact values in both color spaces**: OKLCH (for perceptual editing/theming) and sRGB hex (for contexts needing a literal value, e.g. data-URIs).
7. **Comment every token with its source CSS file** and, critically, **flag values that are "baked"** — hard-coded into a generated output (like an SVG or data-URI) rather than referenced live. Baked values require manual re-sync whenever the source token changes; document this liability at the point of baking, not after the fact.
8. **Include both light and dark theme variants** with all four-value substitutions needed for a complete palette swap (not just the primary color).
9. **Version-control the token doc with the project's real brand values** — never leave a generic/placeholder template in the repo once real values are known.
10. **Treat the token list as a versioned contract**: token *names* are the API. Renaming or removing a token is a MAJOR change (breaks every consumer referencing it); adding a new token is MINOR.

### Extending an existing system
11. **When adding tokens to an established design system, derive new values from existing primitives** rather than inventing a parallel scale — e.g., derive a new "projection" type scale from container-query percentages of the existing type ramp, so the new surface inherits proportional relationships instead of drifting from the base system.
12. **When incorporating a new logo asset**, document the extraction rationale in the commit/PR (e.g., "dark-key the neon glow, not light-key it, because luminance ≈ alpha preserves the glow effect"), commit a master-copy asset at high resolution, and build a reproducible generation script that deterministically scales/keys/crops from that master — so future re-provisioning is a script re-run, not a manual re-derivation.

## Gotchas

- Markdown-converted page content silently discards the CSS you need — always fetch raw HTML/CSS directly.
- Popular page-builder frameworks (Divi and similar) leave signature default colors in the stylesheet that will pollute an occurrence-count ranking if not explicitly filtered out.
- A "baked" token (hard-coded into a generated asset) is a hidden maintenance liability — every baked value needs an explicit comment noting it won't auto-update, or it will silently drift from the source token.
- Treating token names as a stable contract (not just their values) is what prevents downstream breakage — a value change is safe, a name change/removal is not.
