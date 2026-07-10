---
description: Generate a new on-brand AC "PCB phosphor console" badge for the current repo — interview (prefilled with any supplied values), author the dark SVG as a structural sibling of the AC_DESIGN gallery, then emit the full 8-file dark/light variant set.
---

Apply the `ac-logo` skill and execute its **generate** operation.

An optional message may supply `concept:`, `product:`, `subtag:`, or `theme:` clauses —
prefill the interview with them and only ask (via a single batched `AskUserQuestion`) for
what is still missing. Author the dark badge per
`AC_DESIGN_ROOT/docs/logo-design-system.md`, verify it against the Brand checklist, then
run the bundle's `scripts/make-variants.mjs` for the 8-file set.
