---
description: Redraw the current repo's existing logo as an on-brand AC "PCB phosphor console" badge — keep the mark's subject, replace its style per the AC design system, then emit the full 8-file dark/light variant set.
---

Apply the `ac-logo` skill and execute its **reskin** operation.

This operation is **self-contained**: read the existing logo in the current repo, extract
its subject, and redraw it per `AC_DESIGN_ROOT/docs/logo-design-system.md`. Do **not**
delegate to any other skill (in particular, do not invoke `logo-restylizer`).

Ask via `AskUserQuestion` when the source asset, product name, or replace-vs-add decision
is ambiguous. Finish by running the bundle's `scripts/make-variants.mjs` on the redrawn
dark SVG.
