# shared/workflows/

Reserved namespace (D7) — README-only until a vendor-neutral orchestration document is
ready to land here.

## Class boundary (verbatim, requirements §5)

> a shared workflow is a vendor-neutral orchestration *document* a human or agent
> follows; anything that installs and triggers as a skill belongs in a vendor skill
> tree.

That is: a `shared/workflows/` entry is read and followed — by a human, or by an agent
being handed the document as instructions in-context. It is never installed into a
vendor's skill-loading mechanism, never carries vendor-specific trigger frontmatter, and
never auto-fires. The moment an asset needs to install and trigger as a skill, it
belongs under `claude/skills/`, `codex/skills/`, or `gemini/skills/` instead — not here.

## Vendor-neutral test

Applies as stated in `shared/README.md` (D1): no vendor-specific frontmatter contract,
tool syntax, or install-path convention. A workflow document that references a specific
vendor's tool-call syntax or slash-command mechanics fails this test and does not belong
here.

## Adding the first workflow

This directory holds only this README until a real workflow document is ready (D7).
When one lands, add its conventions (naming, structure, expected format) to this README
in the same PR.
