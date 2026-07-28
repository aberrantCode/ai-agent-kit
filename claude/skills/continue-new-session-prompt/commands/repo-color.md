---
description: Show or change the current repo's Windows Terminal tab color in the per-repo color registry
---

The `continue-new-session-prompt` skill assigns every repo one Windows Terminal tab color so spawned
sessions for the same checkout are visually grouped. This command inspects and edits that registry
(`~/.claude/repo-colors.json`) for the **current repo**.

Let `S` = `<skill-dir>/scripts` (the `continue-new-session-prompt` skill's `scripts/` directory).
Interpret the command arguments as follows and run the matching script, then report the result
tersely:

- **No arguments** — show the current repo's assigned color (assigning one on first sight):

  ```
  pwsh -NoProfile -File S/resolve-repo-color.ps1 -WorkingDirectory .
  ```

- **A color** (`#RGB` / `#RRGGBB`, e.g. `/repo-color #FFD866`) — pin that color for the current repo:

  ```
  pwsh -NoProfile -File S/manage-repo-colors.ps1 -Action set -Repo . -Color '<hex>'
  ```

- **`list`** — print the whole registry:

  ```
  pwsh -NoProfile -File S/manage-repo-colors.ps1 -Action list
  ```

- **`reset-top [N]`** — clear the registry and re-seed the N most active repos (default 5) from the
  AC palette. Confirm with the user before running this, since it discards all current assignments:

  ```
  pwsh -NoProfile -File S/manage-repo-colors.ps1 -Action reset-top -Count <N>
  ```

- **`preview`** — open one Windows Terminal window with a colored tab per registered repo:

  ```
  pwsh -NoProfile -File S/demo-repo-tabs.ps1
  ```

Do not free-hand `wt` or edit the JSON directly — always go through these scripts so the mutex and
key normalization are honored.
