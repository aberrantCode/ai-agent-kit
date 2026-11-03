# Handoff: Resolve sops-secrets' 3 leftover script mentions + prune 2 stale merged branches

You are a fresh Claude Code session with no history of the conversation that led to this prompt.
Two small, independent follow-ups from the 2026-10-12 skill-reference-audit fix batch.

## Orientation

Repo root: `C:\development\ai-agent-kit`. Follow the repo's own `CLAUDE.md`/`AGENTS.md` exactly for
conventions, branch/PR policy, and output discipline — do not restate or reinterpret them.

**Your worktree and branch already exist.** Work in
`C:\development\ai-agent-kit\.worktrees\sops-secrets-script-resolution` on branch
`fix/sops-secrets-script-resolution` (branched from `origin/dev` @ `9e6e6a9`). Do **not** create
another worktree for task 2. Task 1 needs no worktree at all (see below).

## HARD CONSTRAINTS

1. Erik has explicitly authorized merging task 2's PR into `dev` yourself after it's opened and
   validated (regular merge commit) — same authorization as the preceding fix batch (PRs #168–174).
2. Never push directly to `dev`, never touch `main`.
3. `worldview-layer-scaffold` and `worldview-shader-preset` (claude AND codex) remain OUT OF SCOPE
   — erik explicitly doesn't want them touched. Do not investigate or mention them.
4. Task 1 (branch deletion) only ever touches already-merged branches confirmed below — do not
   delete anything else, and re-verify each branch is actually merged into `origin/dev` before
   deleting, don't trust this prompt's claim blindly.
5. If anything looks destructive beyond "delete 2 confirmed-merged remote branches" or "author a
   fix, validate, commit, push, open PR, merge PR" — stop and report rather than improvising.

## State already established — do not redo

- 2026-10-12 skill-reference audit (`docs/reports/2026-10-12-skill-reference-audit.md`,
  PR #167, merged by erik) found 13 bundles with broken references + 1 UNCERTAIN (`sops-secrets`).
- A follow-up fix batch (orchestrator session, same day) resolved all 7 fix tasks as PRs
  #168–174, all merged into `dev`. Two of those PRs' branches were not auto-deleted on merge:
  - `feat/usage-limit-reducer-script` (PR #170, merged)
  - `fix/project-manager-codex-gemini-templates` (PR #169, merged)
- That batch's Task G (PR #172, `fix/sops-secrets-disposition`, merged) resolved most of the
  `sops-secrets` UNCERTAIN finding — it concluded `sops-secrets` is a genuinely-incomplete bundle
  (the `opbta-service`/PR #166 class, not the cross-repo-index `ac-opbta-ops` class) and authored
  its `references/`, `commands/`, and `scripts/sops/` tree. It explicitly carved out and left
  unresolved **3 other inline script mentions** in `claude/skills/sops-secrets/SKILL.md` that
  don't match the `scripts/sops/*.sh` family it did author:
  - `scripts/mcp/setup-venv.sh` (SKILL.md line 35 — "Setup: `bash scripts/mcp/setup-venv.sh`" for
    the Secrets-Broker MCP server)
  - `scripts/get-secret.sh` (SKILL.md line ~63, 174 — the "existing, lower-level `/get-secret`"
    interface, described as "kept as-is... the existing script remains")
  - `scripts/sync-secrets-to-keepass.sh` (SKILL.md line ~115 — backs the `/sync-keepass` command)
  - Read PR #172's full body (`gh pr view 172 --json body --jq '.body'`) for its complete reasoning
    before continuing — it already did the comparative analysis against `ac-opbta-ops` and
    `opbta-service`; do not redo that from scratch, extend it to these 3 remaining paths.

## Task 1 — prune 2 stale merged branches (no worktree, no PR, do this first)

From the main checkout (`C:\development\ai-agent-kit`), confirm each branch is an ancestor of
`origin/dev` (`git merge-base --is-ancestor origin/<branch> origin/dev`), then delete both on the
remote:

```bash
git push origin --delete feat/usage-limit-reducer-script
git push origin --delete fix/project-manager-codex-gemini-templates
```

Prefer the repo's own `github` skill `/prune` operation if you'd rather drive it through that
(it's built exactly for "merged, safe to delete" branches) — either path is fine, just verify
ancestry before deleting either way.

## Task 2 — resolve the 3 leftover sops-secrets script mentions

Same judgment-call pattern as PR #172's Task G. For each of the 3 scripts above, in your worktree:

1. Read the surrounding SKILL.md prose for what each script is claimed to do and who's described
   as owning it.
2. Decide, same as PR #172 did for the other scripts: does `claude/skills/sops-secrets/` own this
   script (genuinely missing → author it), or does it belong elsewhere (e.g. is `scripts/get-secret.sh`
   actually the *pre-existing* `.claude/commands/get-secret.md`'s backing script, living in the
   **consuming repo** rather than this archive bundle — note SKILL.md explicitly calls `/get-secret`
   "the older... interface" that's "kept as-is", which reads differently from the commands PR #172
   already confirmed this skill owns)?
3. For each you conclude the bundle genuinely owns: author it under
   `claude/skills/sops-secrets/scripts/`, narrowly scoped to exactly what the SKILL.md text
   describes — no invented behavior.
4. For each you conclude belongs to the consuming/AC_OPBTA-side repo: leave it, and add one line to
   SKILL.md (near that mention) clarifying it's not a bundle-shipped file, so a future audit
   doesn't re-flag it.
5. State your per-script reasoning in the PR description — same bar as PR #172, this is a judgment
   task, not mechanical authoring.

Then: run `pwsh ./scripts/validate.ps1` (must exit 0), commit (`fix:` or `feat:` per what you did),
push, `gh pr create --base dev`, and — once validate.ps1 is green — `gh pr merge --merge --delete-branch`.

## Reporting

Terse. End with a single numbered list of anything needing a decision. Verify counts/claims before
stating them (e.g. actually check each branch's merge-ancestry before deleting, actually read
PR #172's body before extending its reasoning). Correct any claim in this prompt in one line if you
find it's wrong.

## Finishing

Once both tasks are done and task 2's PR is merged, report the PR number and your per-script
decisions, then stop. Do not delete this prompt file yourself — leave retirement to erik.
