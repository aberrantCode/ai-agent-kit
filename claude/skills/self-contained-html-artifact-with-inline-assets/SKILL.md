---
name: self-contained-html-artifact-with-inline-assets
description: Use when building a portable HTML deliverable (dashboard mockup, presentation, static data browser, branded page) that must open directly in any browser with zero external requests — no CDNs, no relative-path assets, no build step — and correctly render in both light and dark themes.
status: active
version: 2026-07-05
---

# Self-Contained HTML Artifact with Inline Assets

## When to use

Whenever a deliverable needs to be portable enough to email, copy to a USB drive, or open as a bare file — a design-review mockup, a static dashboard, a slide deck, a data browser — and must work with no external fetches, no relative paths, and no server. Also applies when a strict CSP blocks all external hosts (fonts, scripts, images).

## Method

1. **Inline everything.** CSS, SVG icons, and images all go inside the single HTML file. Strip any `@import` statements. Embed images and brand assets as data URIs, or as shrunk raster images if a data URI would bloat the file unacceptably.
2. **Use CSS gradients as placeholder "photos"** when production assets aren't ready yet — this unblocks design review without waiting on an asset pipeline.
3. **Favicons and touch icons**: inline the `<link rel="icon">` / `<link rel="apple-touch-icon">` declarations directly in the HTML `<head>`; don't reference `/static/` paths unless the whole app is genuinely served from that path and you've tested the full pipeline locally. Verify the icon renders and stays legible at both 16px and 32px.
4. **Author SVGs as fully self-contained.** All style, color, and dimension values should be hand-inlined in the SVG itself — no external stylesheet references, no CSS custom properties, no data URIs that depend on the embedding page's context. This is what makes an SVG asset reusable across different pages/themes without extra wiring.
5. **For responsive scaling inside a single artifact**, use container queries (`cqi` units) rather than viewport units — this lets slides/panels scale correctly regardless of what viewport or container they're embedded in.
6. **Theme correctness**: build both a light and dark theme path into the CSS (not just one default). Test with headless screenshots captured with the theme statically pinned and CSS transitions disabled — this avoids capturing a mid-crossfade frame that misrepresents either theme.
7. **For larger artifacts (data browsers, multi-section dashboards), use a generator script** (Python or shell) that assembles the final single-file artifact from modular, readable source pieces at build time. Keep the sources human-editable and the `dist/` output regenerable — don't hand-edit the assembled file directly.
8. **Verify before shipping**: open the file directly in a real browser (not just a preview pane), confirm any dynamic behavior (virtualization, search/filter) works, toggle the theme switch, and confirm no network tab requests are made (proves CSP-safe / fully offline-capable).

## Gotchas

- A data URI SVG embedded in a page CSS variable context looks self-contained but isn't reusable elsewhere — hand-author the SVG so it's independent of the page it started in.
- Testing theme appearance with an active CSS transition captures a blended, wrong-looking frame — always disable transitions before a theme screenshot.
- "Opens in a browser" is not the same as "has zero external requests" — check the network tab, not just visual rendering, especially when a strict CSP is a hard requirement.
- Don't let the generated `dist/` artifact become the source of truth — always edit the modular source pieces and regenerate.

## Diagram

[View diagram](diagram.html)
