---
handoff_id: cmd-opps-26a
title: Orchestrate a fleet — enumerate every command used across history, scan each for improvement opportunities, produce a report + visual-explainer slides
model: opus
base_branch: dev
branch: feat/commands-usage-opportunities
repo: C:\development\ai-agent-kit
---

# Handoff — Orchestrate a command-usage opportunity audit (report + slide deck)

You are a fresh session and you are the **orchestrator**. You do not do the mining and per-command
analysis yourself — you **task subagents** (the `Agent` tool) and synthesize. Your worktree and
branch (`feat/commands-usage-opportunities`, from `dev`) **already exist** — work there; do not
create another.

## 1. Orientation

- Read `C:\development\ai-agent-kit\CLAUDE.md` and `AGENTS.md` and follow them exactly, including the
  subagent model-selection rule (delegate cheap/mechanical work to `model: "haiku"`; moderate
  reasoning to `"sonnet"`; keep only hard synthesis on the frontier model).
- Command definitions live in the archive you are working in: `claude/skills/<skill>/commands/*.md`
  and `claude/commands/*.md`. The generated `CATALOG.md` at the repo root lists the full inventory.

## 2. Hard constraints (first and unmissable)

Running under `--dangerously-skip-permissions`; this section is the only guardrail.

- Transcript access is **strictly read-only**. Never write/move/delete anything under
  `~/.claude/projects/`.
- This is a **discovery + reporting** effort. Do **not** edit any command or skill definition. The
  only files you create are the report and the slide deck (and their PR). Improvement *opportunities*
  are findings for a later effort, not changes to apply now.
- Never state a usage count or "every invocation does X" you did not compute. Tag findings `[V]` /
  `[?]`. "Reasonable suspicion is enough to include" lowers the bar for *listing an opportunity* — it
  does **not** lower the bar for stating a measured fact.
- Work only inside the worktree. If blocked, stop and report.

## 3. State already established (do not redo)

- [V] Read-only transcript library: `claude/skills/session-manager/sub-skills/transcripts/scripts/cc_transcripts.py`
  — import it; do not re-derive discovery/iteration/counting. Mining prior art:
  `claude/skills/session-manager/sub-skills/audit/scripts/mine_dispatches.py`.
- [V] Corpus: 48 project dirs / ~268 `.jsonl` / ~174 MB under `~/.claude/projects/`.
- [V] Baseline command universe via the `<command-name>` invocation marker: **17 distinct commands,
  110 invocations.** Top: `clear` 48, `repo-status` 30, `ship` 8, `update-service` 3, `start-app` 3,
  `opbta-update` 3, then a long tail of 1–2. This is a **floor, not the truth** — see the dead end
  below.

## 4. What we tried / dead ends (apply these)

- **The `<command-name>` marker under-counts custom commands.** `/handoff` shows **0** markers
  despite heavy real use, because much work is triggered by natural language → skill, not by the
  slash command, and some invocations serialize without the marker. So the marker is **necessary but
  not sufficient**: a subagent that counts only markers will under-report. Broaden detection with a
  second signal — user turns whose text begins with `/<name>` — and reconcile the two. Report the
  per-command number from each signal separately rather than a single possibly-wrong total.
- **`cc_transcripts.is_injected()` flags `<command-name>` turns as injected.** To *detect* command
  invocations you must match the marker / leading-slash explicitly; do not drop user turns through
  `is_injected` and expect invocations to survive. Use `is_injected` only to clean the *surrounding*
  human turns you quote as evidence.
- **Exclude non-improvable built-ins** from the opportunity pass: `clear`, `login`, `init` (the CLI
  built-in), and anything not backed by a definition file in this archive. Keep them in the usage
  tally (context), but do not spawn an improvement subagent for them.
- Loose string counts over-report (definitions, descriptions, catalog, planning chatter). Count
  invocations, not mentions.

## 5. The orchestration pipeline (run it in this order)

**Stage A — enumerate (one `model: "haiku"` subagent).** Task it to produce the authoritative
command-usage table: every command actually invoked across history (both detection signals,
reconciled), with per-command invocation count and the list of session ids where it appears, and a
mapping of each command → its owning skill and definition-file path (cross-referenced against
`CATALOG.md` / the `commands/` dirs). Output structured (JSON or a table). Exclude built-ins from the
*improvement* set but keep them in the tally.

**Stage B — per-command opportunity scan (fan out, `model: "sonnet"`, in parallel).** Group the
improvable commands sensibly (by owning skill, or one per command where usage is rich — e.g.
`repo-status`, `ship`). **Dispatch the group subagents in parallel in a single message.** Each reads
(a) the command's definition file(s) in the archive and (b) its real usage episodes in the logs, and
returns improvement opportunities — **reasonable suspicion is enough to include**: unclear output,
repeated/avoidable tool calls, common follow-up questions the command could pre-empt, token-heavy
behavior, confusing recommendations, missing guardrails, drift between the definition and actual
behavior. Each opportunity tagged `[V]`/`[?]` with a one-line evidence pointer (session id + quote).
  - Note: `repo-status` has a dedicated analysis already dispatched separately
    (`feat/repo-status-usage-analysis`). Still include it here at summary depth, but defer to that
    effort for depth and say so, to avoid duplicating its PR.

**Stage C — collect + produce deliverables (collector subagent and/or you).**
1. **Markdown report:** `docs/reports/commands-usage-opportunities.md` — the usage table, then
   per-command/grouping opportunities ranked by impact, each evidence-tagged, with an executive
   summary and a prioritized shortlist of the highest-value improvements across all commands.
2. **Visual-explainer slide deck:** invoke `Skill(visual-explainer)` → `generate-slides` to render a
   self-contained HTML presentation of the report (usage overview, top opportunities, prioritized
   roadmap). Save it under `docs/reports/` and open it for the user.

## 6. Finishing

Rebase onto `origin/dev`, pass `pwsh ./scripts/validate.ps1`, open a PR to `dev` adding the report
and the slide HTML (reference this prompt). The generated slide HTML is a build artifact — note its
line count in the PR summary; it adds no review burden. Sync local to `origin/dev` after merge.
**Do not delete this prompt file.** Report and stop.

## 7. Delegation

This whole task *is* delegation. `model: "haiku"` for Stage A enumeration and any pure
counting/extraction; `model: "sonnet"` for the Stage B per-command scans (moderate reasoning, many
of them, inclusive threshold); keep on your own (Opus) loop only the grouping decisions, the
cross-command prioritization, and authoring the slides. Dispatch Stage B in parallel. Spawn a quick
skeptic subagent to sanity-check the final prioritized shortlist before it ships.

## 8. Delegation logging

Use `~/.claude/skills/session-manager/sub-skills/delegation-ledger/scripts/log-delegation-outcome.ps1`:
log each escalation/redo/dropped subagent task with `-Category`/`-FailureMode`/`-Evidence` and
`-HandoffId cmd-opps-26a`; **once at the end before finishing**, log per-category totals
(`-Outcome ok -Dispatches N`) tagged `-PromptPath <this file>` and `-Branch
feat/commands-usage-opportunities`.

## 9. Reporting

Terse; single numbered decision list per turn; verify counts before stating them; one-line
corrections to any earlier wrong claim.

## 10. Model note

Pinned **Opus** for the orchestrator — grouping, cross-command prioritization, and slide authoring
are the judgement-heavy parts. Push the mining to Haiku and the per-command scans to Sonnet rather
than running the whole fleet on Opus.
