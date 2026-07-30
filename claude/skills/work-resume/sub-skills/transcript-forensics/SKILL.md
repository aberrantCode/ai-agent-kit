---
name: work-resume-transcript-forensics
description: Sub-skill of `work-resume`. How to locate a repo's Claude Code transcripts across all worktree conventions, read the per-session digest, and classify each session's resumption state from its last turn. Read this when you need the classification rubric, the worktree-correlation reasoning, or how to pull extra turns without loading a whole transcript.
---

# Transcript forensics

The domain knowledge behind Step 1–2 of `work-resume`: turning a repo's raw
JSONL history into a labelled "where did each session leave off" picture. The
mechanical extraction is `references/resume-scan.py`; this file is the judgment
layer that reads its output.

## Where transcripts live

Claude Code writes one JSONL per session to
`~/.claude/projects/<slug>/<session-uuid>.jsonl`, where `<slug>` is the
session's launch cwd with every non-alphanumeric char replaced by `-`
(`C:\development\ai-agent-kit` → `C--development-ai-agent-kit`). Each line is one
event; the fields that matter: `type` (`user`|`assistant`|meta), `message.content`
(string or a list of `text`/`thinking`/`tool_use`/`tool_result` blocks),
`timestamp`, `cwd`, `gitBranch`, `isSidechain` (subagent turns — not the
operator's thread, skip them).

## Worktree correlation — trust git identity, not names

A session that ran in a worktree lands in its OWN slug dir (the worktree path is
a different cwd). This workstation uses three worktree conventions, and the
scanner must find sessions under all of them:

| convention | example path | slug embeds origin repo? |
|---|---|---|
| in-repo | `<repo>/.worktrees/<name>` | yes (`<mainslug>--worktrees-…`) |
| sibling | `<repo>-wt/<name>` or `<repo>-wt` | yes (`<mainslug>-wt…`) |
| shared container | `C:\development\.worktrees\<name>`, `C:\development\github-repos-wt\<name>` | **no** — holds several repos' worktrees |

Because the shared containers do not embed the origin repo in their path, name
matching is not enough. The correct identity two worktrees of the same repo
share is their **git common dir** (`git -C <path> rev-parse --git-common-dir`
resolves to the main checkout's `.git` for every worktree). So `resume-scan.py`
correlates by:

1. the main checkout;
2. `git worktree list` — every worktree git tracks, live or prunable, any location;
3. pruned-but-transcripts-remain recovery: worktree-shaped project dirs are
   attributed by identity — slug-embedded ones are trusted, shared-container
   ones are included only if their recorded cwd still resolves to THIS repo.

The one unrecoverable case: a worktree that was pruned AND lived in a shared
container AND whose directory is now deleted — no git trace, no cwd to resolve.
Rare; it simply won't appear. If the operator insists a recent session is
missing, that is the likely cause — say so rather than inventing a candidate.

## The digest fields

Each `sessions[]` entry from `resume-scan.py --format json`:

- `first_prompt` / `last_prompt` — the operator's opening ask (the goal seed) and
  their final ask.
- `last_assistant_tail` — the tail of the last assistant *text* turn. This is the
  primary "what was expected next" signal.
- `ended_mid_action` / `last_event_kind` / `last_tool` — did the session die
  while the agent was mid-tool-call (`assistant_tool` / `tool_result`) rather
  than after speaking to the operator (`assistant_text`).
- `recent_edit_files` — **absolute** paths of the last files edited. Absolute on
  purpose: it reveals when a session launched here actually did its work in a
  *different* repo (see below).
- `branch`, `worktree_path`, `cwd`.

## Classification rubric

Walk the digests newest-first and label each session's **resumption state**:

- **completed** — the last turn wraps up with no promised follow-up ("done",
  "shipped", "nothing open", a summary table with no open items). Skip it.
- **completed-with-optional-next** — done, but the agent offered an *optional*
  recommendation ("you could also…", "a reasonable follow-up would be…"). That
  suggestion is a candidate, even though it is unrelated to the original ask.
- **interrupted-mid-implementation** — `ended_mid_action` is true and the tail
  shows work in progress (mid-edit, mid-plan, "next I'll…" with no closing). The
  session died before finishing. Highest-value candidate.
- **awaiting-operator** — the agent asked a question or laid out choices and
  stopped ("Remaining decisions before any write:", an `AskUserQuestion`, a
  proposed plan). The next move is the operator's answer.

The tail alone is usually enough. When it is a terse "done" and you need the goal
and acceptance criteria to resume intelligently, reconstruct them from
`first_prompt` — and if that is thin, read more turns (below).

## Two traps that produce false candidates

- **Cross-repo excursion.** A session launched in repo A can `cd` into repo B and
  do all its real work there; its transcript still lives under A's slug. Tell by
  `recent_edit_files` pointing outside the target repo. Do **not** offer such a
  session as a resumable thread for A — its work belongs to B. (Real example:
  ai-agent-kit sessions whose edits were all in `C:\development\ac-work-launcher`.)
- **Continued-in-new-session.** A compacted/handed-off session ends with a baton
  ("this session is being continued…") — the *live* thread is the newer session,
  not this one. Prefer the newest session in the chain.

## Reading extra turns without loading the whole file

The digest carries each session's `path`. To pull specific context (the accepted
plan, the acceptance criteria, the last few operator turns) without loading a
multi-MB transcript into context, extract just what you need — e.g. the last N
assistant text turns, or user turns matching a keyword:

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

Adjust the slice/filter to the question. The point is to stay bounded — pull the
handful of turns that pin down the goal, not the whole conversation.
