---
name: sm-mine
description: >
  Sub-skill of `session-manager`. Find patterns in Claude Code session history. Friction mode —
  "what keeps going wrong", "find issues we've hit more than once", "audit our conversation
  history", "what should we change so this stops happening": repeated tool errors, rejections
  and operator corrections → proposed (never applied) CLAUDE.md/rule patches. Knowledge mode:
  mine prior transcripts for domain knowledge when building a skill, doc or knowledge base for
  an existing service or codebase. Optional proposed-patches pass turns repeated operator
  corrections into diff-style CLAUDE.md/rule proposals. Commands: /analyze-conversations,
  /mine-sessions.
---

# mine

Find patterns in Claude Code session history. Two modes, one optional add-on:

| Mode | Use it for | Command |
|---|---|---|
| **Friction** | Recurring tool errors, rejections and operator corrections -> prevention patches | `/analyze-conversations` |
| **Knowledge** | Domain knowledge about a service/codebase that was only ever discussed in sessions | `/mine-sessions` |
| **Proposed patches** (option) | Repeated operator corrections -> diff-style CLAUDE.md / rule proposals, never applied | `/mine-sessions` (or after friction mode) |

Formerly the `analyze-conversations` skill (friction mode) and the
`conversation-history-mining-for-domain-knowledge` skill (knowledge mode).

## Routing: what `mine` is not

- Built-in **`/insights`** already summarises your general session history. For a broad
  "how have my sessions gone" summary, use `/insights`. `mine` covers what it does not:
  recurrence-ranked friction with patches, and domain-knowledge extraction.
- Checking whether a **specific, named rule** was followed ("did I follow rule X") is not
  mining: hand it to [`audit`](../audit/SKILL.md).
- Debugging one live failure, or reviewing one transcript already in context: not for this
  sub-skill.

---

## Friction mode

### Overview

Claude Code stores every session as a JSONL transcript; over months that is hundreds of files
and hundreds of MB. The job is to find issues the agent hit **more than once** and propose
changes that stop them recurring, without loading raw transcripts into context.

**Core principle: the funnel.** A committed extractor reduces ~400 MB of JSONL to a few KB of
structured signal (clustered error signatures + bounded correction excerpts). Only that
distilled report enters context. The script clusters what normalises mechanically (errors); you
cluster what needs judgment (free-text corrections).

**The recurrence axis is distinct sessions, not raw count.** An error that fires 50 times in
one session is one incident. The same error in 8 sessions is systemic. Always rank by session
spread.

### When to use

- "What mistakes do I keep making in these sessions?"
- "Find problems we've hit more than once and how to prevent them."
- "Audit the last two weeks of conversations."
- Periodic self-review before a sprint, or after a frustrating stretch.

### Step 1: run the extractor

```bash
python <session-manager>/sub-skills/mine/scripts/analyze-conversations.py --window 7d
```

Resolve `<session-manager>` to the loaded bundle's directory (the one containing this
`sub-skills/` tree), e.g. `~/.claude/skills/session-manager`. The extractor uses the shared
[`transcripts`](../transcripts/SKILL.md) library. Run it from the repo whose sessions you want
to analyze: it auto-detects that repo's Claude Code project slug from the current directory.

`--window` is flexible; the script adapts its strategy to the value:

| value | meaning |
|---|---|
| `7d`, `30d` | calendar window: sessions touched in the last N days |
| `20s` | session window: the N most-recent sessions by mtime (use for quiet stretches a date window would miss) |
| `2026-05-01` | every session touched on/after that date |
| `all` | the full corpus |

Other flags: `--max-files N` (cap on sessions scanned; oldest past the cap are **dropped and
reported**, never silently truncated), `--min-recurrence N` (error-signature threshold, default
2), `--max-corrections N`, `--include-sidechains` (subagent turns, off by default),
`--project-dir` (auto-derived from the current directory's Claude Code project slug under
`~/.claude/projects/`; pass explicitly to analyze a different repo). Run with `--help` for the
full list.

The script is read-only: it mutates nothing and prints a bounded Markdown report to stdout.
Read that report; do **not** read the transcripts yourself.

### Step 2: read the report

Three sections:

1. **Recurring tool errors**: already clustered by normalised signature, ranked by distinct
   sessions then count. Each row: `sessions | count | tool | signature`. These are mechanical
   findings you can trust as-is.
2. **Operator rejections / interrupts**: counts of times the operator rejected a tool call or
   interrupted. Plus a separate count of parallel-batch cancellations (downstream noise,
   excluded from the error ranking).
3. **Operator corrections**: bounded excerpts of genuine human re-steers, for **you** to
   cluster semantically. Group excerpts that push back on the *same* behaviour. A theme across
   >=2 distinct sessions is a recurring issue.

### Step 3: cluster and define "recurring"

An issue counts as recurring when **either**:
- an error signature appears in >=2 distinct sessions, **or**
- >=2 correction excerpts (different sessions) re-steer the same behaviour.

Merge mechanical errors with the corrections that describe the same root cause (e.g. the
`Permission denied (publickey)` error rows + a correction like "the command you gave me threw
an error" may be the same SSH-key-drift story).

### Step 4: map each issue to a prevention surface

Pick the narrowest home that actually prevents recurrence. (Surfaces below are the conventions
of the repo this was authored for; use the equivalents the target repo has.)

| Issue shape | Prevention surface |
|---|---|
| Technical failure mode (tool/command/API breaks the same way) | New `docs/learnings.md` `ISSUE-NNN` entry (Mistake/Root cause/Fix/Lesson) |
| Mechanically detectable + preventable (file pattern, forbidden command, missing flag) | A **hook** in `.claude/settings.json` (PreToolUse guard) or a pre-commit check under `.githooks/` |
| A hard "never do X" the agent keeps violating | `docs/negative-constraints.md` |
| How the agent should *work* (process/behaviour correction) | A `.claude/rules/*.md` rule, or a `memory/feedback_*.md` file + `MEMORY.md` pointer |
| Recurring diagnostic ("doesn't work on host X" again) | A read-only probe/diagnostic script + a documented runbook entry |
| Operator preference / settled decision being re-litigated | A `memory/project_*.md` or `feedback_*.md` file |

Prefer a **hook or check** when the issue is mechanically enforceable: a guard beats a
paragraph the next agent might skim past. Reserve prose (learnings/rules) for judgment calls.

### Step 5: deliver the list, then draft patches

Output is two-stage: a concise list first, then drafted patches.

**First, the concise list**, one line per recurring issue:

```
1. <issue> - <N sessions / M hits> - <proposed resolution + target surface>
```

Keep it scannable. Lead with the highest session-spread items.

**Then, draft the concrete patches** for the issues worth acting on (the exact `ISSUE-NNN`
text, the rule paragraph, the hook JSON, the memory file) and present them for approval. **Do
not write them until the operator approves**; don't spawn busywork or trivial follow-ups.

### Reading-the-data gotchas

- **`type:user` is overloaded.** It carries genuine human turns, `tool_result` blocks, AND
  harness injections (skill bodies that open with `Base directory for this skill:`,
  `<local-command-caveat>` blocks from `! ` commands, `<system-reminder>`, Honcho memory,
  compaction summaries). The extractor filters these; if you ever parse transcripts by hand,
  replicate that filter or injections drown real corrections ~80:1.
- **Trust `is_error`, not content-sniffing.** A successful verifier that prints `errors: 0` is
  not a failure. The harness sets `is_error: true` on genuine tool failures: key off that.
- **`Cancelled: parallel tool call` is downstream noise.** When one tool in a parallel batch
  fails, the harness cancels its siblings. Those are consequences, not causes: the extractor
  counts them separately and excludes them from the ranking.
- **Long baton prompts are not corrections.** A session-kickoff brief embeds `NEVER`/`don't`
  directives mid-paragraph. A real correction *leads* with the re-steer, so the extractor only
  trusts a lead-in match for long turns.

### Limits

- Correction clustering is yours to do: the script only extracts candidates.
- Heavy windows (`all`) plus a high `--max-files` will scan slowly (streaming, so memory stays
  flat). Narrow the window for routine reviews.
- Sub-agent transcripts are excluded by default; add `--include-sidechains` only when auditing
  agent-dispatched work specifically.

### Real signal this surfaces

A 7-day run over 76 sessions found, among others: `Edit "File has not been read yet"` across
30 sessions; `'dev' is already used by worktree` across ~9; `ssh ...Permission denied
(publickey)` across 3 (the opbta-deploy vs opbta-ansible key drift); `Blocked: sleep N`
(reaching for a forbidden `sleep`); and a correction cluster of "the command you gave me threw
an error" / "don't see that it ran" (the agent claiming completion it hadn't verified). Each
maps cleanly to a surface in Step 4.

---

## Option: proposed patches from repeated corrections

Use when the operator asks to turn "I keep telling you X" into durable rules (the
claude-reflect pattern), or as a follow-on to friction mode. **Proposals only: this sub-skill
never edits CLAUDE.md, rule files or `shared/guardrails/`.**

1. Run the Step 1 extractor with the widest window the operator wants (corrections need volume
   to recur; `30d` or `all` is typical). Keep `--max-corrections` generous.
2. Cluster the **Operator corrections** excerpts semantically: group those that re-steer the
   same behaviour. Keep a cluster only if it spans **>=2 distinct sessions**; record the session
   ids and the count per cluster. Drop one-off corrections and anything that is really a
   one-time task instruction.
3. For each surviving cluster, pick the target by scope: user-wide behaviour -> global
   `CLAUDE.md`; repo-specific -> the repo `CLAUDE.md` or a `.claude/rules/*.md` file;
   reusable across repos -> a `shared/guardrails/<name>.md` snippet. Read the target first and
   skip (or tighten) a cluster the file already covers.
4. Draft a diff-style proposal per cluster:

   ```diff
   --- a/CLAUDE.md
   +++ b/CLAUDE.md
   @@ section: <heading> @@
   +- <imperative rule, one line, in the operator's own wording where possible>
   ```

   Evidence under each proposal: cluster theme, session ids, correction count, 1-2 short
   verbatim excerpts.
5. Present the list ranked by session spread and ask for approval per proposal. Apply nothing.
   If the operator approves, they (or a separate, explicit step) apply the patch.
6. If a cluster is about one *named* existing rule being ignored, route it to
   [`audit`](../audit/SKILL.md) to measure compliance before proposing a rewrite.

---

## Knowledge mode

### When to use

Any time you need load-bearing domain knowledge about a service, system, or process that has
been discussed before but isn't written down anywhere authoritative: building a new skill for
an internal tool, onboarding onto a legacy system, or auditing "what keeps going wrong" across
a fleet of repos. Also use when explicitly asked to analyze recent conversations for patterns
(e.g. "find and analyze all Claude conversations over the past 14 days"). Transcripts capture
failure modes, workarounds, and decisions that current code and logs alone won't reveal: they
encode the "why," not just the "what."

### Method

1. **Mine transcripts, not just logs or current state.** Prior conversations with Claude about
   a service accumulate incidents, constraints, and workarounds that never made it into docs.
   Example: a Honcho skill was built by pulling `DERIVER_FLUSH_ENABLED` behavior, a
   `claude->claude` conclusion-pollution incident, and a 6-day silent auth-key failure directly
   out of conversation history: faster and more accurate than reconstructing them from logs
   after the fact.

2. **Dispatch a search agent over the transcript corpus** rather than reading everything
   serially. Have it search for symptom descriptions, workaround phrasing, and decision language
   ("we changed X because Y", "the actual cause was").

3. **Parse transcripts as structured data, not prose.** JSONL session logs carry tool calls and
   their results as first-class fields: use a read-only funnel script (friction mode's
   `scripts/analyze-conversations.py`, or the [`transcripts`](../transcripts/SKILL.md) library
   for custom queries) to extract them, then cluster errors by a normalized signature (strip
   timestamps/IDs, group by error shape) to surface recurring failure classes across many
   sessions.

4. **Treat the transcript as the arbiter of what happened, not current git/system state.**
   Current state gets masked by later manual remediation: someone fixes the symptom outside the
   session and the repo no longer shows the bug. The transcript is the only record of what the
   agent actually did and claimed at the time, and session-end wrap-ups are where the *intended*
   outcome is stated even if it wasn't fully realized.

5. **Convert one-off discoveries into durable memory via a capture-then-curate workflow:**
   - Agents/operators append diagnostic insights, failure modes, and architectural decisions to
     a lightweight intake file as they're discovered: no ceremony, just append.
   - A designated curator agent periodically sweeps the intake file: dedups entries, allocates
     stable IDs, links related items to existing knowledge, and writes the result into a
     permanent index.
   - This keeps CLAUDE.md (or the main context doc) from ballooning while still making
     discoveries retrievable and linkable by issue ID later.

### Gotchas

- Don't treat current repo/system state as ground truth for "did this bug get fixed": silent
  manual remediation outside the session will make a real recurring bug look resolved.
  Cross-check against the transcript record of what actually happened.
- Clustering needs normalization (strip volatile fields like timestamps/paths/IDs) or every
  error looks unique and no pattern emerges.
- An intake file that's never curated just becomes a second, messier CLAUDE.md: the curator
  pass (dedup + ID allocation + linking) is what makes it durable memory rather than a growing
  pile of notes.
- Measuring "session completion vs. actual delivery" requires reading both the wrap-up (stated
  intent) and the tool-call trace (actual actions): either alone overstates or understates what
  was really delivered.
