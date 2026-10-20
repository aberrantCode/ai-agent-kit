---
name: statusline-modify
description: >
  Sub-skill of `statusline`. Change what the status line displays (segments, color thresholds,
  padding/refresh) or reconcile drift between the live script and the archive asset, editing the
  canonical asset first then redeploying. Triggers on "add cost to my status line", "show the
  model name too", "change the token color thresholds", "make my status line refresh every N
  seconds", "capture my live status line change back to the archive", "my status line drifted".
  Verifies by simulation.
---

# Operation: modify

**Goal.** Apply a requested change to the status line safely. The **archive asset**
(`assets/statusline.sh`) is the single source of truth: edit it first, then redeploy — so the
live copy and the archive never diverge. Display-only knobs (`padding`, `refreshInterval`) are
settings.json edits.

## Output Contract (binding — inlined)

Loadable without the parent SKILL.md. Stay silent during execution; fix recoverable errors
quietly; surface blocking errors verbatim then stop/ask via `AskUserQuestion`. End with one
≤4-line summary plus a table only if something's outstanding. All prompts via `AskUserQuestion`.
Overrides explanatory style.

## Decide the change

If the request is ambiguous (which segment? what threshold?), elicit it via `AskUserQuestion` —
never guess a display the user didn't ask for. Common changes:

| Request | Where | How |
|---|---|---|
| Add/remove a segment (cost USD, model, out tokens) | `assets/statusline.sh` | add/remove the field read + its render block; USD is `cost.total_cost_usd` |
| Change color thresholds | `assets/statusline.sh` | the `pct` >= 80 / >= 50 comparisons |
| Padding / refresh interval | `~/.claude/settings.json` | `statusLine.padding` / `statusLine.refreshInterval` (no script edit) |
| Capture a live edit back to the archive (drift) | asset ← live | copy the reviewed live change into `assets/statusline.sh`, then redeploy so both match |

## Steps

1. **Read the current asset** (`assets/statusline.sh`) and the reference
   (`references/statusline-payload.md`) for the exact field names before editing. Never invent a
   stdin field — check the reference; a field that doesn't exist renders blank (that is the whole
   history of this bug).
2. **Edit the asset** (for script changes) using minimal, well-commented diffs — keep the
   native-`context_window`-first / never-mtime-fallback / digit-sanitize invariants intact. For
   drift-capture, copy the reviewed live change into the asset instead.
3. **Redeploy** by running the `install` operation (`sub-skills/install`) against the default
   target — this keeps live and archive in lockstep. For settings-only knobs, `jq`-merge into
   `~/.claude/settings.json` without clobbering other keys.
4. **Verify by simulation** with both a worktree/handoff-shaped payload (native `context_window`,
   no transcript) and the empty-payload exit-0 case, as in `install` step 6. A blank token
   segment or non-zero exit is a blocking error — stop and surface it.
5. **Summary.** What changed in the asset/settings, that it was redeployed, and the new sample
   render line. Note the archive change still needs to be shipped to the repo via `/ship` if the
   user wants it persisted (this operation edits the working tree, it does not open a PR).
