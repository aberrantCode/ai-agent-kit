# Transcript forensics

The judgment layer behind Steps 1-2 of [resume](../SKILL.md): turning a repo's raw JSONL
history into a labelled "where did each session leave off" picture. The mechanical extraction
is `../scripts/resume-scan.py`; this file reads its output.

## Where transcripts live and how worktrees are found

On-disk layout, the slug encoding, record fields (`type`, `message.content`, `timestamp`,
`cwd`, `gitBranch`, `isSidechain`) and worktree-aware discovery are owned by the shared
library; see [../../transcripts/SKILL.md](../../transcripts/SKILL.md) and
[../../transcripts/references/transcript-data-model.md](../../transcripts/references/transcript-data-model.md).
Do not restate them here. Resume-specific points:

- A worktree session lands in its OWN slug dir. Three conventions exist (in-repo
  `<repo>/.worktrees/<name>`, sibling `<repo>-wt/<name>`, shared containers holding several
  repos' worktrees). Shared containers do not embed the origin repo in the path, so name
  matching is not enough: the script correlates on git common dir (main checkout, then
  `git worktree list` live or prunable, then pruned-recovery by identity).
- **One unrecoverable case:** a worktree that was pruned AND lived in a shared container AND
  whose directory is now deleted has no git trace and no cwd to resolve. It will not appear.
  If the operator insists a recent session is missing, say that rather than inventing a candidate.

## The digest fields

Each `sessions[]` entry from `resume-scan.py --format json`:

- `first_prompt` / `last_prompt`: the operator's opening ask (goal seed) and final ask.
- `last_assistant_tail`: tail of the last assistant *text* turn; the primary "what was expected
  next" signal.
- `ended_mid_action` / `last_event_kind` / `last_tool`: did the session die mid-tool-call
  (`assistant_tool` / `tool_result`) rather than after speaking (`assistant_text`).
- `recent_edit_files`: **absolute** paths of the last files edited. Absolute on purpose: it
  reveals when a session launched here did its work in a *different* repo.
- `branch`, `worktree_path`, `cwd`.

## Classification rubric

Walk the digests newest-first and label each session's **resumption state**:

- **completed**: the last turn wraps up with no promised follow-up ("done", "shipped",
  "nothing open", a summary with no open items). Skip it.
- **completed-with-optional-next**: done, but the agent offered an *optional* recommendation
  ("you could also...", "a reasonable follow-up would be..."). That suggestion is a candidate,
  even if unrelated to the original ask.
- **interrupted-mid-implementation**: `ended_mid_action` is true and the tail shows work in
  progress (mid-edit, mid-plan, "next I'll..." with no closing). Highest-value candidate.
- **awaiting-operator**: the agent asked a question or laid out choices and stopped
  ("Remaining decisions before any write:", an `AskUserQuestion`, a proposed plan). The next
  move is the operator's answer.

The tail alone is usually enough. When it is a terse "done" and you need the goal and
acceptance criteria, reconstruct them from `first_prompt`, then read more turns (below).

## Two traps that produce false candidates

- **Cross-repo excursion.** A session launched in repo A can `cd` into repo B and do all its
  real work there; its transcript still lives under A's slug. Tell by `recent_edit_files`
  pointing outside the target repo. Do **not** offer it as a thread for A.
- **Continued-in-new-session.** A compacted or handed-off session ends with a baton ("this
  session is being continued..."); the *live* thread is the newer session. Prefer the newest
  session in the chain.

## Reading extra turns without loading the whole file

The digest carries each session's `path`. Pull only the turns that pin down the goal, not a
multi-MB transcript:

```bash
python - "$SESSION_PATH" <<'PY'
import json, sys
turns=[]
for line in open(sys.argv[1], encoding="utf-8"):
    line=line.strip()
    if not line: continue
    d=json.loads(line)
    if d.get("isSidechain"): continue
    if d.get("type") in ("user","assistant"):
        c=d.get("message",{}).get("content")
        t = c if isinstance(c,str) else " ".join(
            b.get("text","") for b in c if isinstance(b,dict) and b.get("type")=="text")
        if t.strip(): turns.append((d["type"], t))
for role, t in turns[-8:]:              # last 8 real turns
    print(f"\n### {role}\n{t[:1200]}")
PY
```

Adjust the slice or filter to the question. Library-based scripts should prefer
`cc_transcripts.iter_messages` over this ad-hoc loop.
