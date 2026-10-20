# Scanner: ac-repo-radar

Files scanned: 33 (32 from `C--development-ac-repo-radar` + 1 from the
`feat-omni-search-and-channel-scan` worktree project), filtered to the `-mtime -7`,
non-`subagents/` set as specified. Subagent transcripts were excluded from scope per
the brief; top-level session transcripts only.

## F-RR-01 — `/prune`'s remote-branch delete has no "already gone" pre-check, so a normal cleanup run reports failures that aren't real failures
- **Type**: bug
- **Maps to**: `prune` sub-skill (`claude/skills/github/sub-skills/prune/SKILL.md`, Step 5: `git push origin --delete <branch>`); the same unguarded pattern is used ad hoc by manual cleanup scripts observed in these transcripts
- **Source**: recurring across 6 top-level transcripts — `a6d3969c-4264-436d-a1ca-e1478f2893f4.jsonl`, `bf161853-2df9-4e1a-83ae-737210e6f5c6.jsonl`, `666352ae-fa6b-4119-9556-cac788fc0d79.jsonl`, `72149906-9d14-4741-bfe1-b98273b12824.jsonl`, `77ad21b4-5344-43a8-ba3d-839360c82991.jsonl`, `cd733f08-45c6-401c-9a12-30069b8759fb.jsonl` (sessions spanning 2026-07-17 through 2026-07-21)
- **What happened**: Every one of these sessions did post-merge branch cleanup (worktree remove → local branch delete → remote branch delete) and hit the identical error on the remote-delete step, e.g.:
  ```
  Deleted branch docs/review-console-spec (was 2d42a54).
  error: unable to delete 'docs/review-console-spec': remote ref does not exist
  error: failed to push some refs to 'https://github.com/aberrantCode/ac-repo-radar.git'
  ```
  The cause: this repo has GitHub's "auto-delete branch on merge" behavior (or a prior `/merge` already deleted the remote branch), so by cleanup time the remote ref is already gone. `git push origin --delete <branch>` treats that as a hard, non-zero-exit failure and prints a scary "failed to push some refs" line even though the actual outcome (branch gone remotely) is exactly what was wanted. In every instance the assistant had to visually confirm this was benign rather than a real problem.
- **Proposed enhancement**: Before `git push origin --delete <branch>` in `prune/SKILL.md` Step 5 (and wherever `ship`/`merge` do the same remote cleanup), check `git ls-remote --heads origin <branch>` first. If it returns nothing, skip the delete and record it as "already removed remotely" rather than attempting the push and parsing its failure. This also stops the misleading `error: failed to push some refs...` line from appearing in an otherwise-successful summary.
- **Frequency/severity**: recurring, 6 confirmed instances across 5 days of sessions; low severity (cosmetic/confusing, not data-destructive) but high frequency — this is the single most common github-skill-adjacent friction point in the transcript set.

## F-RR-02 — Windows worktree-lock recovery doesn't account for a live child process holding the file handle
- **Type**: missing-capability
- **Maps to**: `worktree-task-lifecycle` sub-skill (Windows lock-recovery step), inherited by `merge`/`prune`/`ship`'s "Windows worktree-lock footgun" rule
- **Source**: `bf161853-2df9-4e1a-83ae-737210e6f5c6.jsonl` (session 2026-07-21)
- **What happened**: Removing the `review-console-build` worktree failed on the first attempt:
  ```
  failed: The process cannot access the file 'C:\development\github-repos-wt\review-console-build\data\local-dev\logs\proxy.log' because it is being used by another process.
  ```
  This wasn't a stale git handle — it was a genuinely running background dev-server process tree (a `pwsh.exe` → `cmd.exe` → `python.exe` chain running `scripts\dev-proxy.py`, logging to a file inside the worktree). The assistant had to manually run `Get-CimInstance Win32_Process` to find the PID holding the file, then find its parent `cmd.exe`, then find *that* process's own child `python.exe` (the actual writer), before it could kill all three and successfully remove the directory.
  The current skill text (`worktree-task-lifecycle/SKILL.md` lines 150-154, mirrored in `merge`/`prune`/`ship`) treats this as "a transient 'Permission denied' here is benign — git has already untracked the worktree. Retry once; if it still resists, leave it on disk." That guidance is actively wrong for this case: retrying the same remove would never succeed while the dev-server process tree is still alive, and "leave it on disk" is a worse outcome than a 30-second process-tree lookup would have produced.
- **Proposed enhancement**: Add a lock-diagnosis step ahead of the "retry once, then give up" fallback: on a Windows `Remove-Item`/`rm -rf` failure naming a specific locked file, resolve the holding PID(s) (`Get-CimInstance Win32_Process | Where CommandLine -like "*<worktree-path>*"`, or an `openfiles`/handle.exe equivalent), walk up/down the process tree from anything rooted in the worktree path, and kill that tree before falling back to "leave it on disk." This is exactly the scenario the sub-skill's description promises to cover ("Windows file-lock recovery") but the documented procedure doesn't yet handle a live process as the cause, only a lingering git handle.
- **Frequency/severity**: seen once directly, but the pattern (a task's own dev server left running past worktree teardown) is a predictable, repeatable class of failure for any repo whose task lifecycle starts a local server; medium cost (required 4 manual diagnostic round-trips to resolve).

## F-RR-03 — (already remediated) `/release` Step 5 formerly assumed a direct push to `main` always works
- **Type**: bug (historical — confirmed fixed in the current `SKILL.md`)
- **Maps to**: `release` sub-skill (`claude/skills/github/sub-skills/release/SKILL.md`, Step 5)
- **Source**: `3bb41276-6dff-471f-818f-a5878f85720f.jsonl` (session releasing v0.7.0)
- **What happened**: `/release` ran `git checkout main; git merge --no-ff origin/dev -m "release: v0.7.0"; git push origin main` and was rejected by this repo's own pre-push hook (`X Refusing to push directly to 'main' on 'origin'. CLAUDE.md §8: every change to dev lands via a pull request...`). The assistant recovered manually and correctly — reset the local merge, opened a release PR (`gh pr create --base main --head dev`), then hit a second blocker (`mergeStateStatus: BLOCKED`, review required, no second reviewer available for a solo-maintainer repo), diagnosed `enforce_admins == false`, and completed with `gh pr merge --admin`, then opened a *third* PR to sync `dev` back from the merge commit. None of this multi-step recovery was scripted — it was improvised end-to-end.
- **Proposed enhancement**: N/A — verified against the current archive (`claude/skills/github/sub-skills/release/SKILL.md` lines 212–286) and this exact scenario is now handled: Step 5 detects PR-only `main` up front (project-rule grep + `gh api branches/main/protection` + hook scan) and routes to "Route B" (release PR) instead of attempting the direct push, and Route B explicitly anticipates the `enforce_admins`/no-reviewer case with the same `--admin` fallback the transcript improvised. Recording this here only as evidence that the fix was warranted — no further action needed.
- **Frequency/severity**: seen once; was high-cost at the time (3 PRs, 2 blocked merges, manual protection-API introspection) but is resolved in the current skill version.

No other genuine github-skill friction was found in this transcript set. A broad first-pass grep for generic error/friction keywords matched the large majority of the 33 files, but on inspection nearly all of that was unrelated to git/GitHub (app build errors, unrelated tool output, or the skill's own name appearing in the standard installed-skills listing every session carries) rather than actual github-skill friction, and was excluded.
