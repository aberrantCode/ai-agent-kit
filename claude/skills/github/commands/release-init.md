---
description: Provision or repair this repo's release automation to the Release-Automation Standard — a persistent changelog generator plus a tag-triggered workflow that regenerates release notes from git at tag time. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Apply the `github` skill and execute its `release-init` operation (`sub-skills/release-init`).

An optional message may pin the generator choice (e.g. `git-cliff`); otherwise detect the
repo's stack and pick the fitting generator. Confirm every planned write via
`AskUserQuestion` before touching a file; a conformant repo is a no-op.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
