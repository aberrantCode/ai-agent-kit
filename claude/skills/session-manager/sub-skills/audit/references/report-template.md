# Report template

Follow this section order. It's built to survive the reader skimming just the
headline table and the evidence table, per the user's terse-output preference
(`~/.claude/rules/interaction.md`, `~/.claude/CLAUDE.md` Output Discipline) --
lead with the number, back it with rows, don't bury the correction in prose.

```markdown
# <Policy Name> Compliance Audit — <date>

**Policy:** `<exact path to the rule file, e.g. ~/.claude/rules/subagent-model-selection.md>` — <one-line restatement>
**Window:** <start> → <end> (<duration>) · **Scope:** <what was mined — repos, project dirs>
**Session model:** <what this audit session itself ran on, and why>

## Headline

| Metric | Value |
|---|---|
| Total instances found in window | N |
| — compliant | N (%) |
| — confirmed violations | N (%) |
| — ambiguous/justified | N (%) |
| <any policy-specific breakdown, e.g. by requested model, by tool, by session> | ... |

**<One or two sentences reframing the trigger, if the audit was prompted by a specific
number or complaint.>** State plainly if the evidence supports or contradicts the
premise that prompted the audit — this is the single most important sentence in the
report. Don't bury a correction to the initial premise in the middle of the doc.

## Method

- What ground-truth source was mined and why (cite the specific files/mechanism).
- What correctness check was performed BEFORE trusting the extraction at scale — if a
  bug was found and fixed mid-audit, say so; a report built on an unvalidated script is
  worth less than the reader can tell from the numbers alone.
- Any known data-completeness caveats (e.g. missing parent transcripts) and how they
  were handled — don't silently paper over gaps.
- Whether extraction was delegated to a subagent or run directly, and why (cheap
  mechanical scripts don't need a subagent wrapper; large open-ended reads do).

## Evidence — confirmed violations

One entry per DISTINCT violation pattern, not one row per raw occurrence if many
occurrences share the same root cause (a recursive chain of 3 near-identical dispatches
is one finding with 3 pieces of evidence, not 3 findings). For each:

- **Where:** session/file/timestamp — precise enough that the user could open the exact
  transcript and see it themselves.
- **What happened:** quote or closely paraphrase the actual data (task description,
  model field, nesting), not an inference.
- **Why it counts:** tie back to the specific rule/policy text that was violated.
- **Confidence:** state it. "The descriptions and nesting are unambiguous in the raw
  record" is high confidence; "this plausibly matches but the attribution is indirect"
  is not, and burying that distinction misleads the reader into treating a guess as a
  fact.

## Ambiguous / justified (not counted as violations)

This section exists to stop an eager violation-hunt from overcounting. A dispatch that
technically matches a keyword pattern (e.g. "unset model") is not automatically a
violation if the underlying task genuinely earns the stronger tier by the policy's OWN
stated exceptions. Show your reasoning per item, and don't fold these into the headline
violation count.

## Cross-check against explicit instructions (if applicable)

If the policy is ALSO stated explicitly inside specific prompts/handoffs/skills that
produced some of the sessions in the window (not just as a standing rule), this is the
sharpest signal available -- an instruction present in the literal text that generated a
session, checked against what that session's transcript actually shows. Table: prompt →
consuming session → what was instructed → what happened → honored/partial/ignored. A
prompt with an instruction but no matching session activity found is its own category --
don't force it into honored or violated; say "no activity found" and note what that
could mean.

## The <adjacent/softer> question (lower confidence)

If digging turns up a related-but-distinct pattern that's outside the literal scope of
the rule being audited (e.g. the rule targets subagent dispatch specifically, but the
data shows the MAIN loop also frequently does the same kind of work directly), don't
silently drop it and don't silently fold it into the primary violation count either --
name it as a separate, lower-confidence observation. This is often where the real
story turns out to live (see the model-effort audit: the "100% Opus" trigger figure
was actually a main-loop phenomenon, not a subagent-delegation failure).

## Proposed fixes (PROPOSALS ONLY — state explicitly that nothing was applied)

If enforcement would live outside the current repo (e.g. global `~/.claude/settings.json`,
hooks, or rule-file wording), propose changes as fenced snippets IN THE REPORT ONLY.
Never write these to the real config as part of producing the report -- the audit is
read-only by design; a report that quietly patches the thing it's auditing has
compromised its own evidence.

Prefer *warn* over *block* when the false-positive cost of blocking is real (a hook
can't tell "unset model, should be haiku" apart from "unset model, correctly inheriting
a deliberately stronger tier for judgment work" -- only the dispatching agent's own
reasoning can, per the ambiguous/justified section above).

## Confirmation

Explicit checklist restating that the audit didn't modify transcripts, config, or repo
code, didn't merge/push/PR anything, and didn't delete/modify the prompt or task that
requested the audit. This is the section a skeptical reader checks first if they're
worried the audit itself did something it shouldn't have.
```

## Rendering

Save the report as `<date>-<slug>.review.md` under `~/.agent/reports/` (create the dir
if missing) and open it with `code <path>` so it renders pre-formatted --
`~/.claude/rules/markdown-review.md` documents why (`*.review.md` is bound to VS Code's
markdown preview editor in this user's settings; plain `.md` stays editable text).
