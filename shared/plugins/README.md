# shared/plugins/

Reserved namespace (D7) — README-only until an entry is ready to land here.

## Purpose

A pure reference list of external plugins and addons relevant across vendors (Claude
Code, Codex CLI, Gemini CLI, and others) — not the plugins themselves, not their
installation logic, just a vetted catalog of what exists and where it came from.

## Every entry carries provenance and a vetting status

When entries are added, each one must record:

- **Provenance** — where the plugin comes from (repo URL, marketplace, author).
- **Vetting status** — `vetted` or `unvetted`.

No entry is added without both fields. An `unvetted` entry is a placeholder for
something noted but not yet reviewed; it is not a recommendation.

## No ownership claims about plugin-precedence

This directory is a reference list only. It makes **no ownership claims** about
plugin-precedence *declarations* (which plugin wins when multiple plugins could handle
the same trigger, load order, override rules, etc.). That concern belongs to
skills-manager's `external-skill-intake` sub-skill (`docs/reorg/charter.md` §4) once
that sub-skill ships. Until then, `shared/plugins/` documents *what plugins exist*, not
*how they are prioritized*.

## Adding the first entry

This directory holds only this README until a real plugin reference entry is ready
(D7). When one lands, add the entry format (naming, required fields, provenance/vetting
schema) to this README in the same PR.
