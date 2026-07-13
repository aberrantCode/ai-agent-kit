---
name: react-virtualization-with-jsdom-measurement
category: Frontend & UI
description: Use when implementing or testing row/item virtualization (react-window, TanStack Virtual) for large lists (1000-10k+ rows) in a React app whose test suite runs under jsdom rather than a real browser.
status: active
version: 2026-07-05
---

# React Virtualization with jsdom Measurement

## When to use

Implementing windowed/virtualized rendering for large lists or grids (react-window,
TanStack Virtual, or a hand-rolled equivalent) where the test suite runs in jsdom.
jsdom does not perform real layout, so virtualization code that depends on measured
element sizes needs a deliberate testing strategy — this is that strategy.

## Method

1. **Seed non-zero layout in test setup.** jsdom's `getBoundingClientRect()` returns
   all-zero rects by default. Stub it in `vitest.setup.ts` (or equivalent) to return
   a fixed non-zero height (e.g. `height = 640`) for all elements. This unblocks
   `measureElement`-based (dynamic) sizing so tests don't have to fall back to a
   fixed `estimateSize` just because jsdom can't measure.

2. **Use a fixed-height row renderer with absolute positioning** for the actual
   implementation: mount only the visible viewport (e.g. ~25 rows for a 10k+ row
   list) while keeping the full dataset in memory, and position each row with
   inline `top: pos * rowHeight`.
   - Critical: the row container must be `position: absolute`, not `relative` —
     with `relative`, the inline `top` offset compounds with normal document flow
     instead of being the sole positioner, producing visibly wrong (stacking or
     overlapping) rows.

3. **Test the DOM shape, not pixels.** In jsdom, assert things jsdom can actually
   represent correctly: rendered row count matches the viewport window (not the
   full dataset), the scroll-sizer div's height equals `total_rows * rowHeight`,
   and text content assertions match what's actually in the DOM.

4. **Scope assertions to a specific container** (e.g. the grid vs. the card-list
   variant) when multiple layout variants render in the same test DOM — otherwise
   `getByText`/`getByRole` queries fail with "multiple elements found" even though
   the component itself is correct.

5. **Verify in both environments.** jsdom tests prove virtualization *behavior* and
   *content* (right rows exist, right count, right total height) — they do not
   prove pixel-perfect visual layout. Confirm smooth scrolling and correct visual
   virtualization separately in a real browser.

## Gotchas

- `display:none` elements measure 0 height in jsdom (unlike real browsers) — a
  virtualized tree mounted inside a hidden container (e.g. an inactive tab) won't
  get real measurements and can silently defeat windowing logic in tests without
  an obvious failure.
- Because the `getBoundingClientRect` stub returns the same height for all elements,
  expanded/dynamic-height content still lands fully in the DOM in jsdom even though
  visually it wouldn't grow the same way in a browser — text-content assertions
  remain valid, but don't infer real visual row-growth from jsdom test behavior.
- `position: relative` on the row wrapper is a common bug that only shows up
  visually (rows overlap/misplace) — it will not fail any content-based jsdom test,
  so it must be checked by eye in a real browser, not assumed safe because tests pass.
- Dynamic `measureElement` sizing requires the `getBoundingClientRect` shim to exist
  in test setup ahead of time — without it, tests either fail or force falling back
  to a fixed `estimateSize`, which doesn't exercise the same code path as production.

## Diagram

[View diagram](diagram.html)
