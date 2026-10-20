---
description: Capture a CLAUDE.md/AGENTS.md file, a section of one, or pasted content into shared/guardrails/ as a new vendor-neutral guardrail with frontmatter
---

Apply the `guardrails-manager` skill and execute the /archive-guardrail operation on the
provided source (a file path, a section, or pasted content). Derive and confirm the guardrail
frontmatter via AskUserQuestion, strip vendor-specific syntax from the body, and write it under
`shared/guardrails/`.
