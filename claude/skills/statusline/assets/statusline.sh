#!/usr/bin/env bash
# Claude Code status line — context/token aware, worktree- and /handoff-safe.
#
# Claude Code pipes a JSON payload to stdin on every render and prints whatever
# this script writes to stdout as the status line. This renders:
#
#     <model>  <pct>% · <ctx> ctx · <out> out   |   <branch> <status>
#
# TOKEN SOURCE — read the native `.context_window` stdin object FIRST.
# Claude Code v2.1.x populates it after the first API response REGARDLESS of
# whether any transcript file exists on disk, so it survives worktree- and
# /handoff-spawned sessions. Those spawned sessions have a `subagents/` dir but
# often no flat "<session_id>.jsonl" main transcript, so transcript-parsing (the
# old approach) structurally returns nothing there — which is exactly the
# recurring "no token count in spawned tabs" symptom. Reading `.context_window`
# sidesteps the whole class of transcript-resolution failures.
#
# FALLBACK — only when `.context_window` is absent (older CLI, or before the
# first API response of a session) do we parse THIS session's transcript,
# resolved by session_id (filename "<session_id>.jsonl"). We NEVER fall back to
# "newest .jsonl in the folder": that paints a *different* session's ending
# context onto a fresh one — the original phantom-100k bug.
#
# Dependencies: bash, jq, git, awk. No node/ccusage/pwsh required.

set -uo pipefail
input="$(cat)"

# jq accessor over the stdin payload
j() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

dir="$(j '.workspace.current_dir // .cwd // "."')"
model="$(j '.model.display_name // empty')"

# --- optional debug capture (inert unless the sentinel file exists) ---
# `touch ~/.claude/statusline.debug` to log the token-relevant fields per render
# to ~/.claude/statusline-stdin.log; delete the sentinel to silence. This is how
# blank-token sessions get diagnosed without editing the script.
if [ -f "$HOME/.claude/statusline.debug" ]; then
  printf 'RENDER cw=%s sid=%s tp=%s\n' \
    "$(j '.context_window // "null"' | tr -d '\n' | cut -c1-200)" \
    "$(j '.session_id // "-"')" \
    "$(j '.transcript_path // "-"')" \
    >> "$HOME/.claude/statusline-stdin.log" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# resolve_transcript — echo THIS session's transcript path, or nothing.
# Order: reported transcript_path (if on disk) -> "<proj>/<session_id>.jsonl".
# NEVER "newest file in dir". <proj> is transcript_path's dir when real, else
# derived from cwd via the ~/.claude/projects/ slug.
# ---------------------------------------------------------------------------
resolve_transcript() {
  local tp sid proj
  tp="$(j '.transcript_path // empty')"; tp="${tp//\\//}"
  sid="$(j '.session_id // empty')"
  if [ -n "$tp" ] && [ -f "$tp" ]; then printf '%s' "$tp"; return; fi
  proj=""
  [ -n "$tp" ] && proj="$(dirname "$tp")"
  if [ -z "$proj" ] || [ ! -d "$proj" ]; then
    proj="$HOME/.claude/projects/$(printf '%s' "$dir" | sed 's#[\\/:.]#-#g')"
  fi
  [ -n "$sid" ] && [ -f "$proj/$sid.jsonl" ] && printf '%s' "$proj/$sid.jsonl"
}

# cumulative OUTPUT tokens across THIS session's main-thread records
transcript_out() {
  jq -rs '
    [ .[]? | select((.isSidechain // false) == false) | .message.usage?.output_tokens // empty ]
    | add // "" ' "$1" 2>/dev/null
}
# context FILL from the LAST main-thread usage record (fallback when no stdin cw)
transcript_ctx() {
  jq -rs '
    [ .[]? | select((.isSidechain // false) == false) | .message.usage? // empty ] as $u
    | ( ($u | last)
        | ( (.input_tokens // 0) + (.cache_read_input_tokens // 0)
          + (.cache_creation_input_tokens // 0) + (.output_tokens // 0) ) ) // "" ' \
    "$1" 2>/dev/null
}

# strip anything non-numeric (guards a stray \r from CRLF streams on Git-Bash)
digits() { printf '%s' "${1//[!0-9]/}"; }

pct=""; ctx=""; out=""; win=""
cw="$(j '.context_window // empty')"
if [ -n "$cw" ] && [ "$cw" != "null" ]; then
  # --- preferred: native stdin fields (robust in worktree/handoff sessions) ---
  pct="$(digits "$(j '.context_window.used_percentage // empty')")"
  ctx="$(digits "$(j '.context_window.total_input_tokens // empty')")"
  win="$(digits "$(j '.context_window.context_window_size // empty')")"
  # cumulative output is NOT a stdin field; enrich from transcript when resolvable
  t="$(resolve_transcript)"
  [ -n "$t" ] && out="$(digits "$(transcript_out "$t")")"
fi

if [ -z "$ctx" ]; then
  # --- fallback: parse this session's transcript (older CLI / pre-first-response) ---
  t="$(resolve_transcript)"
  if [ -n "$t" ]; then
    ctx="$(digits "$(transcript_ctx "$t")")"
    out="$(digits "$(transcript_out "$t")")"
    win="${win:-200000}"
  fi
fi

# derive percentage from ctx/window when the CLI didn't hand us used_percentage
if [ -z "$pct" ] && [ -n "$ctx" ] && [ -n "$win" ] && [ "$win" -gt 0 ] 2>/dev/null; then
  pct="$(awk -v c="$ctx" -v w="$win" 'BEGIN{printf "%.0f", (c/w)*100}')"
fi

# humanize: 45231 -> 45.2k (empty stays empty)
humanize() {
  local t="$1"
  [ -z "$t" ] && { printf ''; return; }
  if [ "$t" -ge 1000 ] 2>/dev/null; then awk -v t="$t" 'BEGIN{printf "%.1fk", t/1000}'
  else printf '%s' "$t"; fi
}
ctx_h="$(humanize "$ctx")"
out_h="$(humanize "$out")"

# --- git branch (<=25 chars) + status (dirty marker, ahead/behind upstream) ---
branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
if [ -n "$branch" ] && [ "${#branch}" -gt 25 ]; then branch="${branch:0:24}…"; fi
status=""
if [ -n "$branch" ]; then
  [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ] && status="*"
  ab="$(git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || echo '')"
  if [ -n "$ab" ]; then
    behind="$(printf '%s' "$ab" | awk '{print $1}')"
    ahead="$(printf '%s' "$ab" | awk '{print $2}')"
    [ "${ahead:-0}" -gt 0 ] 2>/dev/null && status="${status}↑${ahead}"
    [ "${behind:-0}" -gt 0 ] 2>/dev/null && status="${status}↓${behind}"
  fi
fi

# --- assemble (ANSI: dim model, threshold-colored token block, cyan branch, yellow status) ---
DIM='\033[2m'; CYAN='\033[36m'; YEL='\033[33m'; RST='\033[0m'
BGREEN='\033[1;32m'; BYEL='\033[1;33m'; BRED='\033[1;31m'

# token block as plain text first (omit whichever parts are missing)
tok=""
[ -n "$pct" ] && tok="${pct}%"
if [ -n "$ctx_h" ]; then
  [ -n "$tok" ] && tok="${tok} · ${ctx_h} ctx" || tok="${ctx_h} ctx"
fi
if [ -n "$out_h" ]; then
  [ -n "$tok" ] && tok="${tok} · ${out_h} out" || tok="${out_h} out"
fi

line=""
[ -n "$model" ] && line="${DIM}${model}${RST}"

if [ -n "$tok" ]; then
  # color the whole token block by percentage: <50 green, 50-80 yellow, >80 red
  col="$BGREEN"
  if [ -n "$pct" ]; then
    if [ "$pct" -ge 80 ] 2>/dev/null; then col="$BRED"
    elif [ "$pct" -ge 50 ] 2>/dev/null; then col="$BYEL"; fi
  fi
  seg="${col}${tok}${RST}"
  [ -n "$line" ] && line="${line}  ${seg}" || line="${seg}"
fi

if [ -n "$branch" ]; then
  if [ -n "$line" ]; then line="${line}  ${DIM}|${RST}  ${CYAN}${branch}${RST}"
  else line="${CYAN}${branch}${RST}"; fi
  [ -n "$status" ] && line="${line} ${YEL}${status}${RST}"
fi

printf '%b' "$line"
