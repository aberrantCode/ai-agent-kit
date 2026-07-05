#!/usr/bin/env python3
"""
analyze-conversations.py — distil Claude Code <-> operator transcripts into a
small, structured "recurring issue" signal the agent can reason over WITHOUT
loading hundreds of MB of JSONL into context.

Read-only. Mutates nothing. Prints a bounded Markdown report to stdout.

The companion skill is `.claude/skills/analyze-conversations/SKILL.md` and the
slash command is `/analyze-conversations`. See the skill for how to turn this
report into a concise issue list + drafted prevention patches.

Transcript location (Claude Code, Windows):
  ~/.claude/projects/<project-slug>/<session-uuid>.jsonl
one JSON event per line. Event `type` is user|assistant|<snapshot/meta>.
`message.content` is a string OR a list of blocks (text|thinking|tool_use|
tool_result). Tool failures carry `is_error: true` on the tool_result block.
Genuine operator messages are `type:user` text blocks that are NOT tool_result
and NOT hook-injected (system-reminder / Honcho / Caveat).

WINDOW — configurable, strategy adapts to the value:
  --window 7d        events with mtime in the last 7 days   (calendar window)
  --window 30d       last 30 days
  --window 20s       the 20 most-recent sessions by mtime   (session window)
  --window 2026-05-01  every session touched on/after that date
  --window all       every session in the project dir
Internal logic: once the resolved file set exceeds --max-files (default 80),
the oldest files past the cap are DROPPED and the drop is reported (never
silently truncated). Files are always streamed line-by-line, so memory stays
flat regardless of corpus size.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime, timezone

# Windows console defaults to cp1252; force UTF-8 so excerpts never crash print.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HOME = os.path.expanduser("~")


def _default_project_dir():
    """Derive the current repo's Claude Code project slug from cwd.

    Claude Code stores transcripts under ~/.claude/projects/<slug>/, where the
    slug is the absolute path with every non-alphanumeric char replaced by '-'
    (e.g. C:\dev\My_App -> C--dev-My-App). Override with --project-dir.
    """
    slug = re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    return os.path.join(HOME, ".claude", "projects", slug)


DEFAULT_PROJECT_DIR = _default_project_dir()

# --- operator-correction lexicon -------------------------------------------
# Phrases that signal the operator is correcting / re-steering the agent.
# Strong = high-confidence correction; weak = needs the agent's eyes.
STRONG = [
    "no, ", "no.", "nope", "that's wrong", "thats wrong", "that is wrong",
    "that's not", "thats not", "that is not", "incorrect", "you forgot",
    "you didn't", "you didnt", "you did not", "i told you", "i already told",
    "revert", "undo that", "that broke", "this is broken", "not what i asked",
    "not what i wanted", "you were supposed to", "you should have",
    "why did you", "stop ", "don't ", "do not ", "never do", "wrong again",
    "again you", "as i said", "like i said", "i said to",
]
WEAK = [
    "actually,", "actually ", "instead", "rather than", "shouldn't", "shouldnt",
    "you keep", "every time", "always do", "please don't", "no need to",
    "that's not what", "re-read", "reread", "read the rule",
]

# Hook-injected / non-human user content to exclude from "operator messages".
# `type:user` is overloaded: it carries genuine human turns, tool_result blocks,
# AND harness injections (skill bodies, local-command caveats, compaction
# summaries). Without this filter, injections drown real corrections ~80:1.
INJECTED_PREFIXES = (
    "<system-reminder>", "[honcho memory", "[request interrupted",
    "caveat:", "<command-name>", "<command-message>", "<local-command-stdout>",
    "<local-command-caveat>", "base directory for this skill",
    "this session is being continued", "launching skill:", "tool loaded.",
    "<user-prompt-submit-hook>", "your questions have been answered",
)

# Tool-result content fragments that mean "the operator rejected the action".
REJECTION_MARKERS = (
    "the user doesn't want to proceed", "tool use was rejected",
    "user rejected", "request interrupted by user",
)

UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
HEX_RE = re.compile(r"\b[0-9a-f]{7,}\b")
NUM_RE = re.compile(r"\d+")
PATH_RE = re.compile(r"([A-Za-z]:)?[\\/][\w.\-\\/]+")
WS_RE = re.compile(r"\s+")


def err_signature(text: str) -> str:
    """Normalise an error string to a comparable signature."""
    t = text.lower().strip()
    t = UUID_RE.sub("<uuid>", t)
    t = PATH_RE.sub("<path>", t)
    t = HEX_RE.sub("<hex>", t)
    t = NUM_RE.sub("<n>", t)
    t = WS_RE.sub(" ", t)
    return t[:160]


def cmd_signature(command: str) -> str:
    """Cluster a Bash command by its leading verb + first salient token."""
    c = command.strip().split("\n")[0]
    toks = [x for x in re.split(r"\s+", c) if x]
    if not toks:
        return "(empty)"
    head = toks[0]
    # skip env-prefix / sudo to reach the real verb
    i = 0
    while i < len(toks) and ("=" in toks[i] or toks[i] in ("sudo", "env")):
        i += 1
    if i < len(toks):
        head = toks[i]
        sub = toks[i + 1] if i + 1 < len(toks) and not toks[i + 1].startswith("-") else ""
        return f"{os.path.basename(head)} {sub}".strip()
    return os.path.basename(head)


def is_injected(text: str) -> bool:
    low = text.lstrip().lower()
    return low.startswith(INJECTED_PREFIXES)


def correction_hits(text: str):
    """Classify a human turn as a correction. A real correction LEADS with the
    re-steer; long task-briefs only match because they embed `NEVER`/`don't`
    directives mid-paragraph, so for long turns we only trust a lead-in match."""
    stripped = text.strip()
    low = " " + stripped.lower()
    lead = low[:200]
    if len(stripped) > 600:
        # task brief / baton prompt — only a correction if it OPENS with one
        if any(p in lead for p in STRONG):
            return "strong"
        return None
    if any(p in low for p in STRONG):
        return "strong"
    if any(p in low for p in WEAK):
        return "weak"
    return None


def first_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text":
                return b.get("text", "")
    return ""


def parse_window(window: str, files):
    """Return (selected_files, note). `files` is [(path, mtime), ...] newest first."""
    window = (window or "7d").strip().lower()
    now = time.time()
    m = re.fullmatch(r"(\d+)d", window)
    if m:
        cut = now - int(m.group(1)) * 86400
        sel = [(p, mt) for p, mt in files if mt >= cut]
        return sel, f"calendar window: last {m.group(1)} day(s)"
    m = re.fullmatch(r"(\d+)s", window)
    if m:
        n = int(m.group(1))
        return files[:n], f"session window: {n} most-recent session(s)"
    if window == "all":
        return list(files), "full corpus"
    try:
        d = datetime.strptime(window, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        cut = d.timestamp()
        sel = [(p, mt) for p, mt in files if mt >= cut]
        return sel, f"since {window}"
    except ValueError:
        cut = now - 7 * 86400
        return [(p, mt) for p, mt in files if mt >= cut], "default: last 7 day(s) (unparsed window)"


def excerpt(text: str, n: int = 220) -> str:
    t = WS_RE.sub(" ", text.strip())
    return (t[:n] + "...") if len(t) > n else t


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--window", default="7d", help="Nd | Ns | YYYY-MM-DD | all (default 7d)")
    ap.add_argument("--project-dir", default=DEFAULT_PROJECT_DIR)
    ap.add_argument("--max-files", type=int, default=80, help="cap on sessions scanned (oldest past cap dropped + reported)")
    ap.add_argument("--max-corrections", type=int, default=120, help="cap on correction excerpts emitted")
    ap.add_argument("--min-recurrence", type=int, default=2, help="min count for an error/command signature to be 'recurring'")
    ap.add_argument("--include-sidechains", action="store_true", help="include subagent (isSidechain) turns")
    args = ap.parse_args()

    if not os.path.isdir(args.project_dir):
        print(f"ERROR: project dir not found: {args.project_dir}", file=sys.stderr)
        return 2

    files = []
    for fn in os.listdir(args.project_dir):
        if fn.endswith(".jsonl"):
            p = os.path.join(args.project_dir, fn)
            try:
                files.append((p, os.path.getmtime(p)))
            except OSError:
                pass
    files.sort(key=lambda x: x[1], reverse=True)

    selected, note = parse_window(args.window, files)
    dropped = 0
    if len(selected) > args.max_files:
        dropped = len(selected) - args.max_files
        selected = selected[: args.max_files]

    # --- accumulators -------------------------------------------------------
    err_counter = Counter()                 # signature -> count
    err_example = {}                        # signature -> (tool, excerpt)
    err_sessions = defaultdict(set)         # signature -> {session}
    rejection_count = 0
    rejection_sessions = set()
    cancelled_count = 0          # downstream parallel-batch cancellations (noise)
    corrections = []                        # (ts, session, strength, excerpt)
    sessions_scanned = 0
    lines_scanned = 0

    for path, _mt in selected:
        sessions_scanned += 1
        sid = os.path.basename(path)[:8]
        tool_names = {}  # tool_use_id -> tool name (per-file)
        try:
            fh = open(path, encoding="utf-8")
        except OSError:
            continue
        with fh:
            for line in fh:
                lines_scanned += 1
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not args.include_sidechains and ev.get("isSidechain"):
                    continue
                etype = ev.get("type")
                msg = ev.get("message") or {}
                content = msg.get("content")
                ts = ev.get("timestamp", "")

                # assistant tool_use -> remember tool name by id
                if etype == "assistant" and isinstance(content, list):
                    for b in content:
                        if isinstance(b, dict) and b.get("type") == "tool_use":
                            tool_names[b.get("id")] = b.get("name", "?")
                    continue

                if etype != "user":
                    continue

                # user turns carry EITHER tool_result blocks OR human text
                if isinstance(content, list):
                    handled_tool = False
                    for b in content:
                        if not isinstance(b, dict):
                            continue
                        if b.get("type") == "tool_result":
                            handled_tool = True
                            raw = b.get("content")
                            txt = raw if isinstance(raw, str) else first_text(raw)
                            low = (txt or "").lower()
                            if any(mk in low for mk in REJECTION_MARKERS):
                                rejection_count += 1
                                rejection_sessions.add(sid)
                            # Trust the harness's is_error flag — content-sniffing
                            # mis-flags successful output that merely says "errors: 0".
                            if not b.get("is_error"):
                                continue
                            # Downstream noise: when one tool in a parallel batch
                            # fails the harness cancels its siblings. Count, skip.
                            if "cancelled: parallel tool call" in low:
                                cancelled_count += 1
                                continue
                            tname = tool_names.get(b.get("tool_use_id"), "?")
                            sig = err_signature(txt or "")
                            if not sig:
                                continue
                            err_counter[sig] += 1
                            err_sessions[sig].add(sid)
                            err_example.setdefault(sig, (tname, excerpt(txt or "")))
                    if handled_tool:
                        continue
                    text = first_text(content)
                else:
                    text = content if isinstance(content, str) else ""

                if not text or is_injected(text):
                    continue
                # genuine operator message
                hit = correction_hits(text)
                if hit:
                    corrections.append((ts, sid, hit, excerpt(text)))

    # Failed Bash commands: re-derive by pairing within files would need a 2nd
    # pass; instead we surface them through the error signatures above and the
    # agent reads the Bash examples. (Kept simple + single-pass on purpose.)

    # --- emit bounded Markdown report --------------------------------------
    out = []
    w = out.append
    w("# Conversation analysis report")
    w("")
    w(f"- Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}")
    w(f"- Project dir: `{args.project_dir}`")
    w(f"- Window: {note}")
    w(f"- Sessions scanned: {sessions_scanned}  |  events scanned: {lines_scanned:,}")
    if dropped:
        w(f"- **NOTE: {dropped} older session(s) dropped past --max-files={args.max_files}.** Re-run with a narrower window or higher cap to include them.")
    w("")

    # Recurring tool/error signatures, ranked by distinct-session spread then count
    recurring = [
        (sig, c, len(err_sessions[sig]))
        for sig, c in err_counter.items()
        if c >= args.min_recurrence
    ]
    recurring.sort(key=lambda x: (x[2], x[1]), reverse=True)
    w(f"## Recurring tool errors  ({len(recurring)} signatures with count >= {args.min_recurrence})")
    w("")
    w("Ranked by distinct sessions (systemic) then raw count. A signature in many")
    w("sessions is a systemic issue; many hits in ONE session is usually one incident.")
    w("")
    if recurring:
        w("| sessions | count | tool | error signature (normalised) |")
        w("|---:|---:|---|---|")
        for sig, c, ns in recurring[:40]:
            tname, ex = err_example.get(sig, ("?", ""))
            w(f"| {ns} | {c} | {tname} | {ex.replace('|', '/')[:120]} |")
    else:
        w("_None above threshold._")
    w("")

    # Operator rejections
    w("## Operator rejections / interrupts")
    w("")
    w(f"- Rejections/interrupts: {rejection_count}  across {len(rejection_sessions)} session(s)")
    w(f"- Parallel-batch cancellations (downstream noise, excluded above): {cancelled_count}")
    w("")

    # Operator corrections (for the AGENT to cluster semantically)
    corrections.sort(key=lambda x: x[0], reverse=True)
    shown = corrections[: args.max_corrections]
    strong_n = sum(1 for c in corrections if c[2] == "strong")
    w(f"## Operator corrections  ({len(corrections)} total, {strong_n} strong; showing {len(shown)} newest)")
    w("")
    w("Cluster these SEMANTICALLY — group excerpts that re-steer the SAME behaviour.")
    w("A theme appearing across >=2 distinct sessions is a recurring issue.")
    w("")
    if shown:
        w("| when | session | strength | excerpt |")
        w("|---|---|---|---|")
        for ts, sid, strength, ex in shown:
            when = ts[:10] if ts else "?"
            w(f"| {when} | {sid} | {strength} | {ex.replace('|', '/')} |")
    else:
        w("_No correction-pattern turns matched._")
    w("")
    w("---")
    w("Next: per the analyze-conversations skill, cluster the above into a concise")
    w("issue list (issue / frequency / proposed resolution mapped to a repo")
    w("prevention surface) and draft the patches for operator approval.")

    print("\n".join(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
