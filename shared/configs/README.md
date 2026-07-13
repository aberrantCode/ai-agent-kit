# shared/configs/

Reserved namespace (D7) — README-only until a vendor-neutral config fragment is ready to
land here.

## Purpose

Reusable configuration fragments any vendor's agent (or a human) can drop into a
project — snippets, templates, or partials that are not tied to one vendor's
frontmatter contract, tool syntax, or install-path convention (the D1 vendor-neutral
test in `shared/README.md`).

## No secrets — pointers only

**This directory never contains secret material** — no API keys, tokens, connection
strings, credentials, or anything secret-shaped. Config fragments here point at where a
secret comes from (an environment variable name, a secrets-manager reference, a
placeholder), never the secret's value.

This rule is enforced mechanically: once T4 lands, `scripts/audit.ps1`'s secret-shaped
content scan runs over everything under `shared/` and fails (error severity) on any
match. Until then, treat this as a binding manual rule — do not commit anything here
that would fail that scan.

## Adding the first config fragment

This directory holds only this README until a real config fragment is ready (D7). When
one lands, add its conventions (naming, format, how to reference secrets by pointer) to
this README in the same PR.
