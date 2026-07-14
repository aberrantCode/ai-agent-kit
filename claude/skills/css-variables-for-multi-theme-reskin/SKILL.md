---
name: css-variables-for-multi-theme-reskin
category: Frontend & UI
description: Use when a mockup, dashboard, or app needs light/dark modes and/or multiple brand palettes, or when asked to "reskin" or "retheme" an existing interface without touching its structure or interaction logic.
status: active
version: 2026-07-05
---

# CSS Variables for Multi-Theme Reskin

## When to use

Any interface that needs more than one visual identity — light/dark mode, multiple
brand palettes, or a "create a themed copy of this existing dashboard" request.
Also use when explicitly asked to restyle, retheme, or reskin something that already
works: the goal is a pure token substitution, not a rebuild.

## Method

1. **Define base tokens as CSS custom properties at `:root`.** Name them semantically
   (`--brand`, `--muted`, `--surface`, `--accent`), not by literal color, so the same
   name means "the right color for this theme" everywhere they're used.

2. **Scope theme variants with attribute selectors**, not separate stylesheets or
   duplicated rule sets:
   ```css
   :root { --brand: oklch(60% 0.15 250); }
   :root[data-theme="light"] { --surface: oklch(98% 0 0); }
   :root[data-theme="dark"]  { --surface: oklch(15% 0 0); }
   ```
   Every component references the tokens, never hardcoded colors — the palette lives
   in one place.

3. **Derive tinted/translucent surfaces from base tokens with `color-mix()`** rather
   than defining a second hardcoded color per surface:
   ```css
   background: color-mix(in oklch, var(--brand) 15%, transparent);
   ```
   This keeps badges, glows, hover states, and buttons all following the same base
   hue automatically when the base token changes.

4. **Prefer a modern color space (`oklch`) over hex/rgb** when the source allows it.
   `oklch` makes "same hue, different lightness" a one-value change (adjust the L
   channel), which is exactly the transform a light/dark or brand-variant reskin needs.

5. **Wire the toggle to a single DOM attribute**: a theme switcher just does
   `document.documentElement.dataset.theme = 'dark'` (or the brand name). Because
   every color is a variable reference, the entire palette recomputes with no other
   JS and no re-render logic needed.

6. **Verify both themes render correctly in the same session** without a page reload
   — toggle back and forth and confirm all surfaces update, not just the obvious ones
   (check badges, glows, disabled states, borders).

## Gotchas

- If you find yourself restructuring HTML or changing interaction/behavior to "make
  the retheme work," you've left the pattern — a reskin should be a token-value swap,
  nothing else changes.
- Keep theme tokens isolated from component CSS (a tokens file/section separate from
  component rules) so future re-themes never require touching component code again.
- Don't hardcode a second literal color for "the tinted version of X" — derive it via
  `color-mix()` from the base token, or it will drift out of sync on the next brand
  change.
- This turns a brand reskin into a data change (new token values) instead of a code
  refactor — if a "new brand" request still requires editing component files, the
  token boundary wasn't drawn correctly.

## Diagram

[View diagram](diagram.html)
