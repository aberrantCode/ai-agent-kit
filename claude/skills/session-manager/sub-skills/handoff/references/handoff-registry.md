# Handoff registry — `~/.claude/telemetry/handoffs.jsonl`

One JSON object per line, append-only, never rewritten in place. A live row's `child_sid` is
completed by a *second* appended row sharing the same `handoff_id` (the child's own first-turn
self-report), not an in-place edit of the first — the file is tailed and greppable, and an
in-place rewrite risks a reader seeing a half-written line.

## Fields

| Field | Type | Meaning |
|---|---|---|
| `handoff_id` | string | Stable id for one handoff. Live: the id the `handoff` sub-skill puts in the generated prompt's frontmatter, passed through to `launch-claude-session.ps1`. Forensic: taken from the prompt's own frontmatter `handoff_id` if it has one (every prompt written after this PR does); otherwise synthesized as `bf-<prompt-slug>` since no live id exists for pre-registry handoffs. |
| `ts` | string | UTC `yyyy-MM-ddTHH:mm:ssZ`. Live: row-write time. Forensic: the matched child session's first-turn timestamp. |
| `parent_sid` | string \| null | The authoring session's id. Live: `$env:CLAUDE_CODE_SESSION_ID`, captured **before** the launcher clears it for the child (the child would otherwise inherit the parent's id instead of getting its own). Forensic: usually unrecoverable — `null` rather than guessed. |
| `child_sid` | string \| null | The spawned session's id. `null` until known. Live dispatch rows start `null`; a later row with the same `handoff_id` and a non-null `child_sid` is the child's self-report. Forensic rows carry the matched id directly, or `null` if no confident match was found — never guessed. |
| `prompt` | string | Absolute path to the `docs/PROMPTS/*.md` file the handoff was built from. |
| `branch` | string | The task branch named in the prompt / passed to dispatch. |
| `repo` | string | Absolute path to the repo the handoff targeted. |
| `source` | `"live"` \| `"forensic"` | `live`: written at dispatch time by `launch-claude-session.ps1`, or by the child's own first-turn self-report. `forensic`: written after the fact by the backfill script, reading transcript history. |
| `confidence` | float, `0.0`–`1.0` | `live` rows are always `1.0` — there is nothing to infer, the launcher wrote the id into the very prompt the child is told to read. `forensic` rows are scored by match strength (below). |

## Why `child_sid` starts null

A dispatch-time row is written the moment `launch-claude-session.ps1` spawns the child — before
the child has taken a single turn. The session id is assigned by the Claude Code CLI when the
child's own transcript file is created; the launcher cannot know it in advance, so the row it
writes is deliberately incomplete (`child_sid: null`, `source: live`, `confidence: 1.0`). It is
completed one of two ways, both by appending, never by editing the first row:

1. **Live self-report.** The handoff prompt's **Correlation** section (see `handoff/SKILL.md`)
   instructs the child to append its own row — same `handoff_id`, `source: live`,
   `confidence: 1.0`, its real `child_sid` — on its first turn. A reader joins on `handoff_id` and
   prefers whichever row has a non-null `child_sid`.
2. **Forensic backfill**, for handoffs that predate this registry or whose child skipped the
   self-report step (crashed before its first turn, a copy-mode prompt pasted by hand, etc.). The
   backfill script (`handoff/scripts/backfill_handoff_registry.py`) matches a `docs/PROMPTS/*.md`
   file to the child transcript whose first non-injected user turn is the launcher's opener
   referencing that prompt, and appends a `source: forensic` row.

Never fabricate a `parent_sid`, `child_sid`, or `confidence`. An unresolved join is a `null`
`child_sid` and a low `confidence` — not a guess.

## Confidence scoring (forensic rows only)

| Match strength | Confidence |
|---|---|
| Child's first non-injected user turn is the exact launcher opener containing the prompt's full absolute path | high — 0.9–1.0 |
| Opener matches on basename only (path differs: moved file, different machine, different drive letter) | medium — 0.5–0.8 |
| Multiple candidate children match the same prompt | the kept best match scores ≤0.5; the ambiguity (all candidates) is logged in the backfill report, never silently resolved |
| No candidate found | row is still written: `child_sid: null`, `confidence: 0.0` — a documented miss, not a skipped row |

Do **not** join on the prompt's title heading or its de-dated filename slug — that join measured
0% precision for reasons documented in
`../../transcripts/references/transcript-data-model.md`.

## Idempotency key

Re-running the backfill must not duplicate rows. Before appending a forensic row for a given
prompt, the writer reads the existing registry and skips any prompt that already has a row with
the same `(prompt, child_sid)` pair — including a prior `child_sid: null` row for that exact
prompt, which is left in place rather than re-appended. The registry can therefore be re-run
safely as new prompts accumulate; it only ever adds rows for prompts it has not already resolved
(or already recorded as unresolved).

## Writers

- **Live:** `session-manager/sub-skills/dispatch/scripts/launch-claude-session.ps1` (dispatch-time
  row), and the child's own first-turn self-report instructed by the handoff prompt's Correlation
  section.
- **Forensic:** `session-manager/sub-skills/handoff/scripts/backfill_handoff_registry.py`.

## Readers

- `delegation-ledger/scripts/log-delegation-outcome.ps1` (`-HandoffId`) and
  `delegation-report.ps1` correlate delegation-ledger rows to a handoff.
- Any future audit of handoff throughput or precision reads this file directly — flat JSONL,
  greppable without a parser, one record per line.
