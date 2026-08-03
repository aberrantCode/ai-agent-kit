---
name: compliance-audit
description: Audit Claude Code session history for whether a stated policy or rule was actually *followed in practice* by past agent behavior — not whether code or a file currently complies with a rule right now (that's a different job: use security-review, code-review, or analyze-features instead). One exception: when the real question is whether a required process step behind a generated artifact was actually run — e.g. "was CHANGELOG.md actually regenerated before that release, or hand-edited" — that's still a behavior question, not a content-quality one. The rule can come from a rule file, a project doc, or something the user said earlier in conversation — named or not. "Past behavior" includes moments ago in this very conversation, not just earlier sessions — a live self-check like "did you actually use AskUserQuestion just now instead of asking inline?" is the same audit, just a narrower window. Use this whenever the user wants to check past session behavior against such a rule: "did I actually follow the haiku-delegation rule", "were any subagents spawned without the required isolation", "audit my last N hours/days of sessions for X compliance", "check whether we've been using AskUserQuestion instead of inline questions", "did any session push directly to dev/main despite the PR-only rule", "mine my transcripts for violations of Z". This is a backward-looking compliance check, not a forward-looking efficiency pass or a content audit — trigger this skill when the question is "did we already follow rule X," even when phrased around spend/tokens/model choice (not usage-limit-reducer's "how do I use fewer tokens" with no rule in play) or when a usage/spend report seems to contradict a standing instruction (the aggregate number is very often not the real story; this skill traces it back to individual, checkable records instead of trusting the dashboard) — and not security-review's turf when the ask is about current code/secrets content rather than past process. Investigates real transcript files directly rather than trusting a summary, and produces a rendered, evidence-backed report proposing (never applying) fixes.
---

# Compliance Audit

Someone (often the user themselves) states a rule about how Claude Code sessions should
behave — delegate mechanical work to a cheap model, always use `AskUserQuestion` for
decisions, never push straight to `dev`, always run the test suite before claiming done.
Stating a rule and a rule actually being followed are different facts, and the gap
between them only shows up by reading what sessions *actually did*, not by re-reading
the rule itself. This skill mines real transcript data to close that gap and reports
what it finds, with evidence, not vibes.

**The core discipline: verify, don't assume.** An aggregate dashboard number ("100% of
spend on Opus") is a hint, not evidence — it can be produced by a completely different
mechanism than the one it looks like it implicates (see the worked example in
`references/report-template.md`: a "100% Opus spend" figure that looked like a
subagent-delegation failure turned out to be a main-loop phenomenon instead — the
subagents were almost entirely compliant). Never write the headline number until you've
traced it back to individual, checkable records.

## Step 1 — Pin down exactly what's being audited

Before mining anything, get precise about three things (ask via `AskUserQuestion` if
any is genuinely unclear from the request — don't guess and burn a mining pass on the
wrong question):

1. **The policy itself.** A path to a rule file (`~/.claude/rules/*.md`, a project
   `CLAUDE.md` section), or a plain-English restatement if there's no file. Read the
   actual rule text — don't paraphrase from memory, since the exact wording usually
   contains the exceptions that matter (e.g. "unless the task is genuinely
   reasoning-heavy" is not a detail you can skip and still classify correctly). Carry
   the exact path into the rendered report's header (see `references/report-template.md`)
   — reading the rule yourself isn't the same as telling the reader which rule you
   checked. A first eval run of this skill produced a report that reasoned about "the
   rule" fluently throughout but never once printed its file path, while a plain
   baseline run of the same task did cite it — an easy, specific gap to reintroduce if
   this line gets skimmed.
2. **The window.** A time range (default: last 48h if unspecified — say so explicitly
   rather than silently picking one) and a scope (all repos, or one project/repo
   substring). If the question is about *this very conversation* ("did you just do X a
   minute ago"), the window is trivial — the current session's own transcript is right
   here in context, so skip the mining pipeline entirely and just check directly. Still
   apply the same discipline as everywhere else in this skill (cite the specific rule,
   quote the actual turn, don't just assert compliance from memory) — a live check is a
   narrower audit, not a lower-rigor one.
3. **What "violation" means for THIS policy.** This determines the mining strategy in
   Step 2 — a policy about model selection needs different data than a policy about
   git push targets. Don't force every audit through the same lens just because one
   worked well last time.

## Step 2 — Pick a mining strategy that matches the policy shape

The one universal, validated tool this skill bundles is
`scripts/mine_dispatches.py` — it answers "what subagents were dispatched, with what
model, and what was the main-loop model at the time" by reading
`subagents/**/*.meta.json` as ground truth (more reliable than parsing `.jsonl` tool_use
blocks alone — see `references/transcript-data-model.md` for exactly why, including two
real counting bugs already fixed in the script). Use it directly for any policy about:

- subagent/model/effort selection ("delegate mechanical work to haiku")
- whether work was fanned out to subagents at all vs. done in the main loop
- nested/recursive delegation chains not converging to the intended tier

```bash
python3 <SKILL_DIR>/scripts/mine_dispatches.py --since "2026-07-31 00:00:00" [--project-substring ac-repo-radar]
```

For policies about something else, the *ground truth changes* but the same discipline
applies — find the record that's actually authoritative, not the summary that's
convenient:

- **Behavioral/interaction policies** ("always use AskUserQuestion", "never invent a
  fact") — grep assistant message text in `.jsonl` for the pattern (e.g. a `?` in
  assistant prose not immediately followed by an `AskUserQuestion` tool_use in the same
  or next turn). The signal lives in message content, not in meta.json.
- **Tool-usage/git-workflow policies** ("never push to dev/main directly", "never
  `--no-verify`") — grep `tool_use` blocks named `Bash` for the literal command text.
  The signal is a command string, not a model field.
- **Cross-check either way against explicit prompts.** If the user's setup has
  handoff/prompt documents that state the policy explicitly for a specific session (this
  user's convention: `docs/PROMPTS/**` with a stated section like `## Delegation`), find
  those in the window and match "what was instructed" against "what that session's
  transcript shows." An instruction stated in the literal text that produced a session
  is the single sharpest compliance signal available — sharper than the standing rule
  file, because there's no ambiguity about whether the session's author knew about it.

Don't invent a fourth mining strategy for a policy type not listed above without first
checking whether one of the three above actually fits — most behavioral policies reduce
to "grep messages", "grep tool_use", or "read meta.json", once you're specific about
what a violation would look like on disk.

## Step 3 — Validate before trusting the extraction at scale

Whatever script or grep you're running, sanity-check it on a small, hand-verifiable
slice **before** running it across the full window and reporting the output as fact. The
bundled `mine_dispatches.py` is already validated (see the module docstring and
`references/transcript-data-model.md`), but if you write anything new — a grep pattern,
a different correlation join — spot-check its output against 2-3 records you can read
by hand first. An extraction bug that silently inflates or deflates a count is much
harder to catch after the fact than before you've committed to a headline number.

## Step 4 — Classify, don't just count

For each candidate instance, decide: **compliant**, **confirmed violation**, or
**ambiguous/justified**. The third bucket exists because policies have exceptions
(reasoning-heavy work correctly earning a stronger model; a task genuinely needing a
human judgment call kept in the main loop) — a keyword match that ignores the policy's
own stated exceptions will overcount violations and make the report less trustworthy,
not more thorough. When in doubt, read the actual task content (the full prompt, not
just its one-line description) before deciding — a description alone often isn't enough
to tell mechanical work from judgment work.

Watch specifically for **recursive/nested delegation** — a subagent that itself spawns
subagents (check `parentAgentId` / `spawnDepth` in meta.json). A single wrong tier
choice at the top can propagate through several hops before self-correcting, and that's
a more interesting (and more fixable) finding than any single dispatch in isolation.

## Step 5 — Write the report

Follow `references/report-template.md` section-by-section — it encodes the shape that
survives skimming (headline number first, evidence table with precise citations,
ambiguous/justified kept separate from confirmed violations, proposed fixes clearly
marked as proposals). Save to `~/.agent/reports/<date>-<slug>.review.md` and open with
`code <path>` so it renders — see `~/.claude/rules/markdown-review.md` if that
convention isn't already familiar in this environment.

## Hard constraints — this skill is read-only by construction

An audit that modifies the thing it's auditing has destroyed its own evidence. Every
invocation of this skill:

- **Never modifies, deletes, or reformats a transcript**, `~/.claude` config
  (`settings.json`, hooks, rules), or any repo's code as part of producing the report.
- **Never merges, PRs, or pushes anything.** If the audit runs in a scratch worktree,
  that worktree is scratch — cleanup is the user's call, not something to do
  automatically at the end.
- **Proposes fixes as fenced snippets in the report only.** Never apply a proposed hook,
  config change, or rule-wording edit as part of the audit itself — that's a separate,
  explicitly-approved follow-up action, not something bundled into "producing the
  report."
- If a task genuinely seems to require a forbidden action (applying a fix, modifying a
  transcript to test something), stop and say so in the report rather than improvising
  around the constraint.

## Reference files

- `scripts/mine_dispatches.py` — the validated subagent-dispatch miner (Step 2). Read
  its docstring before modifying it; the two bugs it fixes are non-obvious and easy to
  reintroduce.
- `references/transcript-data-model.md` — the on-disk shape of `.jsonl` transcripts and
  `meta.json` subagent records, every gotcha found so far, and the git-bash/Windows
  path-translation trap that makes `glob()`/`os.path.exists()` silently return nothing
  for a path that clearly exists.
- `references/report-template.md` — the report section skeleton, with the reasoning
  behind each section's placement.
