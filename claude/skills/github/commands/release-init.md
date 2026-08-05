---
description: Provision or repair this repo's release automation to the Release-Automation Standard — a persistent changelog generator plus a tag-triggered workflow that regenerates release notes from git at tag time. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/release-init/SKILL.md` to run its `release-init` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:release-init)`.

An optional message may pin the generator choice (e.g. `git-cliff`); otherwise detect the
repo's stack and pick the fitting generator. Confirm every planned write via
`AskUserQuestion` before touching a file; a conformant repo is a no-op.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
