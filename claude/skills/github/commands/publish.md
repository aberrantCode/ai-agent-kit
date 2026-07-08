---
description: Publish the current local project as a new hardened GitHub repository — gitleaks pre-commit hook, .gitignore/.gitattributes, main + dev branches, and branch protection requiring PRs on both. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Apply the `github` skill and execute its `publish` operation (`sub-skills/publish`).

An optional message may specify visibility ("public" / "private"); otherwise ask via
`AskUserQuestion`. Security hardening (gitleaks, branch protection) is never optional.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
