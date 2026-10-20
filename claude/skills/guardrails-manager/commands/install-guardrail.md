---
description: Deploy a guardrail from shared/guardrails/ into a project's CLAUDE.md/AGENTS.md/GEMINI.md (or a profile rules file), per its applies-to and scope
---

Apply the `guardrails-manager` skill and execute the /install-guardrail operation with the
provided guardrail name and optional target directory. Resolve the guardrail, confirm the
destination via AskUserQuestion per its `scope`/`applies-to`, and insert its body (not the
archive frontmatter) into the destination file without duplicating an existing rule.
