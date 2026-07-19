# shared/prompts/

Reusable, standalone prompts — plain text or markdown any vendor's agent can consume.
First occupant of `shared/` (D6); relocated here from the Claude-specific prompts
directory because these prompts carry no Claude-specific frontmatter contract, tool
syntax, or install-path convention (the D1 vendor-neutral test in `shared/README.md`).

## Naming

- One prompt per file.
- Filename is a short, descriptive, kebab-case or free-form slug ending in `.md`
  (existing examples: `expert-review-and-enhancement.md`, `techical-author-draft.md`,
  `training-guide-and-manual.md`).
- No numeric prefixes, no vendor names in the filename.

## One-prompt-per-file

Do not bundle multiple unrelated prompts into a single file. If a prompt is a step in a
multi-step sequence (e.g. "draft" then "enhance"), each step still gets its own file;
sequencing is expressed via the optional `use-with` frontmatter field, not by
concatenation.

## Frontmatter

New prompts SHOULD carry frontmatter:

```yaml
---
name: expert-review-and-enhancement
description: One-line summary of what the prompt does and when to use it.
use-with: techical-author-draft.md   # optional — related prompt(s) this is typically chained with
---
```

- `name` (required) — matches the filename stem.
- `description` (required) — one line, human-scannable.
- `use-with` (optional) — filename(s) of related prompts this one is commonly paired or
  sequenced with.

Existing prompts predate this convention and are not required to be retrofitted by this
task; new prompts added to this directory should include frontmatter going forward.
