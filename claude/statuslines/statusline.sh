#!/usr/bin/env bash
# Claude Code status line.
# Shows: tokens in the current context | git branch (<=25 chars) | branch status.
#
# Claude Code pipes a JSON blob to stdin on every render and prints whatever
# this script writes to stdout. Token counts are NOT in that JSON, so we parse
# the JSONL transcript at .transcript_path and read the most recent usage
# record (= current context-window size). To show CUMULATIVE output tokens
# instead, see the note near the jq block below.

set -uo pipefail

input="$(cat)"

# --- locate the working dir + transcript from the stdin JSON ---
dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"

# --- tokens: sum the LAST usage record = current context size ---
# We MUST read only THIS session's transcript. The transcript filename is always
# "<session_id>.jsonl", so session_id is an exact key for the current session.
# Claude's reported transcript_path can be stale (a filename not yet on disk, seen
# in 1M-context / handoff-spawned worktree sessions), so resolve in this order:
#   1. reported transcript_path (normalized), if it's on disk
#   2. "<proj>/<session_id>.jsonl" — the canonical name for THIS session
# where <proj> is the dir named by transcript_path if real, else derived from cwd.
# We do NOT fall back to "newest .jsonl in the dir": that grabs a *different,
# prior* session (its ending 150k+ context) and mislabels a fresh session's fill.
# When the current session's file isn't on disk yet, show no count — correct and
# transient — rather than another session's number.
transcript="${transcript//\\//}"
proj=""
[ -n "$transcript" ] && proj="$(dirname "$transcript")"
if [ -z "$proj" ] || [ ! -d "$proj" ]; then
  proj="$HOME/.claude/projects/$(printf '%s' "$dir" | sed 's#[\\/:.]#-#g')"
fi
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  transcript=""
  [ -n "$session_id" ] && [ -f "$proj/$session_id.jsonl" ] \
    && transcript="$proj/$session_id.jsonl"
fi

# We report two numbers (main-thread records only; a subagent's usage is not this
# session's):
#   tokens = context-window FILL — sum of the LAST record (drives the color gauge)
#   out    = cumulative OUTPUT tokens across the whole session (tracks work done)
tokens=""; out=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  read -r tokens out < <(jq -rs '
    [ .[]? | select((.isSidechain // false) == false) | .message.usage? // empty ] as $u
    | ( ($u | last)
        | ( (.input_tokens // 0)
          + (.cache_read_input_tokens // 0)
          + (.cache_creation_input_tokens // 0)
          + (.output_tokens // 0) ) ) as $ctx
    | ( [ $u[] | .output_tokens // 0 ] | add // 0 ) as $out
    | "\($ctx) \($out)"
  ' "$transcript" 2>/dev/null)
  # strip anything non-numeric (guards against a stray \r from CRLF streams)
  tokens="${tokens//[!0-9]/}"; out="${out//[!0-9]/}"
  case "$tokens" in ''|null) tokens="" ;; esac
  case "$out" in ''|null) out="" ;; esac
fi

# humanize: 45231 -> 45.2k (empty for a missing value)
humanize() {
  local t="$1"
  [ -z "$t" ] && { printf ''; return; }
  if [ "$t" -ge 1000 ] 2>/dev/null; then
    awk -v t="$t" 'BEGIN{printf "%.1fk", t/1000}'
  else
    printf '%s' "$t"
  fi
}
ctx_h="$(humanize "$tokens")"
out_h="$(humanize "$out")"

# --- git branch, truncated to <= 25 chars (24 + single-char ellipsis) ---
branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
if [ -n "$branch" ] && [ "${#branch}" -gt 25 ]; then
  branch="${branch:0:24}…"
fi

# --- branch status: dirty marker + ahead/behind upstream ---
status=""
if [ -n "$branch" ]; then
  if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
    status="*"            # uncommitted changes present
  fi
  ab="$(git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || echo '')"
  if [ -n "$ab" ]; then
    behind="$(printf '%s' "$ab" | awk '{print $1}')"
    ahead="$(printf '%s' "$ab" | awk '{print $2}')"
    [ "${ahead:-0}" -gt 0 ] 2>/dev/null && status="${status}↑${ahead}"
    [ "${behind:-0}" -gt 0 ] 2>/dev/null && status="${status}↓${behind}"
  fi
fi

# --- assemble (ANSI: bold threshold-colored tokens, cyan branch, yellow status) ---
DIM='\033[2m'; CYAN='\033[36m'; YEL='\033[33m'; RST='\033[0m'
# Token color scales with context fill against a 200k window:
#   < 50% green, 50-80% yellow, > 80% red — all bold so the count is never dim.
BGREEN='\033[1;32m'; BYEL='\033[1;33m'; BRED='\033[1;31m'
CTX_MAX=200000
line=""
# Context fill drives the color gauge; cumulative output is appended dim as "· Nk out".
if [ -n "$ctx_h" ]; then
  tok_color="$BGREEN"
  if [ -n "$tokens" ] 2>/dev/null; then
    if [ "$tokens" -ge "$((CTX_MAX * 80 / 100))" ] 2>/dev/null; then
      tok_color="$BRED"
    elif [ "$tokens" -ge "$((CTX_MAX * 50 / 100))" ] 2>/dev/null; then
      tok_color="$BYEL"
    fi
  fi
  line="${tok_color}${ctx_h} ctx${RST}"
  [ -n "$out_h" ] && line="${line} ${DIM}· ${out_h} out${RST}"
fi
if [ -n "$branch" ]; then
  if [ -n "$line" ]; then
    line="${line}  ${DIM}|${RST}  ${CYAN}${branch}${RST}"
  else
    line="${CYAN}${branch}${RST}"
  fi
  [ -n "$status" ] && line="${line} ${YEL}${status}${RST}"
fi
printf '%b' "$line"
