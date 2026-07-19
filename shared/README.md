# shared/

Vendor-neutral assets — reusable across Claude Code, OpenAI Codex CLI, Google Gemini
CLI, and any future vendor, framework, or product. This tree exists alongside the
vendor-first trees (`claude/`, `codex/`, `gemini/`); it never replaces them (D1).

## The vendor-neutral test

An asset belongs in `shared/` only if it passes this test verbatim from
`docs/requirements/canonical-repo.md` §4 (D1):

> an asset qualifies for `shared/` only if it contains no vendor-specific frontmatter
> contract, tool syntax, or install-path convention — plain markdown/config any
> vendor's agent can consume.

If an asset requires a vendor's specific frontmatter schema, tool-invocation syntax, or
install-path convention to function, it belongs under that vendor's tree
(`claude/skills/`, `codex/skills/`, `gemini/skills/`, or the vendor's
`instructions/`/`commands/`), not here.

## The four classes

| Class | Contents |
|---|---|
| `prompts/` | Reusable, standalone prompts — one prompt per file, plain text or markdown. |
| `workflows/` | Vendor-neutral orchestration *documents* a human or agent follows manually. |
| `configs/` | Reusable configuration fragments. No secrets — pointers only. |
| `plugins/` | A pure reference list of external plugins/addons, with provenance and vetting status per entry. |

Each class has its own README documenting its specific conventions — see the README in
each subdirectory.

## Adding a new asset class

New classes are **README-first**: before any asset lands in a new `shared/<class>/`
directory, that directory is created containing only a `README.md` describing its
purpose, conventions, and the vendor-neutral test as applied to that class (mirroring
how `workflows/`, `configs/`, and `plugins/` were reserved in this effort per D7). Only
after the README exists do actual assets get added. This keeps the namespace legible
and the mission discoverable in the tree even before a class has content.
