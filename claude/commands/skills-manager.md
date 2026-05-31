---
description: Scan the Claude profile and all C:\development projects for new or changed skills, agents, and commands. Copy them into this archive under the correct toolset subfolder, update README.md, and print a change summary.
---

# /sync-skills

Apply the `sync-skills` skill to synchronize the AI Agent Kit.

Using your sync-skills domain expertise, execute the following steps:

1. **Discover** all source files from the canonical locations defined in the skill.
2. **Classify** each file as New, Changed, or Unchanged by comparing against the archive counterpart.
3. **Copy** all new and changed files to their archive destinations, creating directories as needed.
4. **Update README.md** — add rows for new skills, update descriptions for changed skills, and increment all counts.
5. **Print** the formatted summary box showing new, updated, skipped, and archive totals.
