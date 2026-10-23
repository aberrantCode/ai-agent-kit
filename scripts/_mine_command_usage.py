#!/usr/bin/env python3
"""
Mine Claude Code command invocations from all transcripts.

Detects command usage via two independent signals:
- Signal 1 (marker): <command-name>X</command-name> XML blocks
- Signal 2 (leading-slash): user text starting with /command-name

Counts per command, maps to definition files, flags built-ins.
"""

import os
import sys
import json
import re
from collections import defaultdict
from pathlib import Path

# ===================== Constants =====================

ARCHIVE_ROOT = r"C:\development\ai-agent-kit"
MARKER_PATTERN = re.compile(r'<command-name>\s*/?([A-Za-z0-9:_-]+)\s*</command-name>')
LEADING_SLASH_PATTERN = re.compile(r'^/([A-Za-z0-9:_-]+)')

BUILTIN_COMMANDS = {
    'clear', 'login', 'logout', 'init', 'compact', 'help', 'model',
    'cost', 'config', 'fast', 'resume', 'agents', 'review', 'security-review'
}

# Import the transcript library
# Try main repo
transcript_paths = [
    os.path.join(ARCHIVE_ROOT, "claude", "skills", "session-manager",
                 "sub-skills", "transcripts", "scripts"),
]

cct = None
for path in transcript_paths:
    if os.path.isdir(path):
        sys.path.insert(0, path)
        try:
            import cc_transcripts as cct
            break
        except ImportError:
            sys.path.pop(0)

if cct is None:
    print(f"ERROR: Could not import cc_transcripts from any path:")
    for p in transcript_paths:
        print(f"  - {p}")
    sys.exit(1)
COMMAND_DEFS_GLOBAL = os.path.join(ARCHIVE_ROOT, "claude", "commands")
SKILLS_ROOT = os.path.join(ARCHIVE_ROOT, "claude", "skills")

# ===================== Functions =====================

def get_first_non_whitespace_token(text):
    """Extract first non-whitespace token from text."""
    stripped = text.lstrip()
    if not stripped:
        return None
    token = stripped.split()[0] if stripped.split() else stripped[0]
    return token

def detect_commands_in_message(text, session_id, msg_index):
    """
    Detect command invocations in a user message via both signals.

    Returns:
      list of (command_name, signal_set) tuples
      where signal_set is a frozenset of {'marker', 'leadingslash'} that fired
    """
    commands_detected = {}  # command_name -> frozenset of signals

    # Signal 1: Marker pattern
    for match in MARKER_PATTERN.finditer(text):
        cmd = match.group(1).lower()
        if cmd not in commands_detected:
            commands_detected[cmd] = set()
        commands_detected[cmd].add('marker')

    # Signal 2: Leading slash (only from first non-whitespace token)
    first_token = get_first_non_whitespace_token(text)
    if first_token and first_token.startswith('/'):
        # Extract command name, allowing for / and optional args after
        match = LEADING_SLASH_PATTERN.match(first_token)
        if match:
            cmd = match.group(1).lower()
            if cmd not in commands_detected:
                commands_detected[cmd] = set()
            commands_detected[cmd].add('leadingslash')

    return [(cmd, frozenset(sigs)) for cmd, sigs in commands_detected.items()]

def find_definition_file(command_name):
    """
    Locate the definition file for a command.
    Returns: (definition_file_path_relative, owning_skill_name) or (None, None)
    """
    # Try global commands first
    global_def = os.path.join(COMMAND_DEFS_GLOBAL, f"{command_name}.md")
    if os.path.isfile(global_def):
        rel = os.path.relpath(global_def, ARCHIVE_ROOT).replace("\\", "/")
        return (rel, None)

    # Try skills' companion commands
    if os.path.isdir(SKILLS_ROOT):
        for skill_name in os.listdir(SKILLS_ROOT):
            skill_cmd_dir = os.path.join(SKILLS_ROOT, skill_name, "commands")
            if os.path.isdir(skill_cmd_dir):
                cmd_file = os.path.join(skill_cmd_dir, f"{command_name}.md")
                if os.path.isfile(cmd_file):
                    rel = os.path.relpath(cmd_file, ARCHIVE_ROOT).replace("\\", "/")
                    return (rel, skill_name)

    return (None, None)

def mine_transcripts():
    """Mine all transcripts and return aggregated command usage."""

    stats = {
        'project_dirs': 0,
        'jsonl_files': 0,
        'sessions_scanned': 0,
    }

    # Tally: command_name -> {
    #   'marker_count': int,
    #   'leadingslash_count': int,
    #   'session_ids': set(),
    # }
    tally = defaultdict(lambda: {
        'marker_count': 0,
        'leadingslash_count': 0,
        'session_ids': set(),
    })

    # Count project dirs
    pdirs = cct.project_dirs()
    stats['project_dirs'] = len(pdirs)

    # Count JSONL files across all projects
    for pdir in pdirs:
        stats['jsonl_files'] += len(cct.jsonl_files(pdir))

    # Mine each session
    for transcript_path, project_slug, session_id, mtime in cct.iter_sessions():
        stats['sessions_scanned'] += 1

        # Iterate through user messages
        for rec, msg in cct.iter_messages(transcript_path, role='user'):
            # Get message text (all_text combines all text blocks)
            text = cct.all_text(msg.get('content', ''))
            if not text:
                continue

            # NOTE: We do NOT filter on is_injected() here because <command-name> blocks
            # are marked as injected but are genuine command invocations we want to count.
            # Only skip obvious system-only prefixes.
            if text.lstrip().lower().startswith(('<system-reminder>', '[honcho memory', '[request interrupted')):
                continue

            # Detect commands in this message
            commands = detect_commands_in_message(text, session_id, None)

            for cmd_name, signals in commands:
                entry = tally[cmd_name]
                entry['session_ids'].add(session_id)

                if 'marker' in signals:
                    entry['marker_count'] += 1
                if 'leadingslash' in signals:
                    entry['leadingslash_count'] += 1

    # Convert session_ids sets to sorted lists, cap at 25 per command
    commands_out = []
    for cmd_name in sorted(tally.keys()):
        entry = tally[cmd_name]
        session_ids = sorted(entry['session_ids'])
        truncated = len(session_ids) > 25
        if truncated:
            session_ids = session_ids[:25]

        definition_file, owning_skill = find_definition_file(cmd_name)
        is_builtin = cmd_name in BUILTIN_COMMANDS
        improvable = definition_file is not None or not is_builtin

        commands_out.append({
            'name': cmd_name,
            'marker_count': entry['marker_count'],
            'leadingslash_count': entry['leadingslash_count'],
            'union_count': entry['marker_count'] + entry['leadingslash_count'],
            'distinct_sessions': len(entry['session_ids']),
            'session_ids': session_ids,
            'session_ids_truncated': truncated,
            'definition_file': definition_file,
            'owning_skill': owning_skill,
            'builtin': is_builtin,
            'improvable': improvable,
        })

    # Sort by union_count descending
    commands_out.sort(key=lambda x: x['union_count'], reverse=True)

    # Build output
    result = {
        'corpus': stats,
        'commands': commands_out,
        'totals': {
            'distinct_commands': len(commands_out),
            'total_union_invocations': sum(c['union_count'] for c in commands_out),
        }
    }

    return result

# ===================== Main =====================

if __name__ == '__main__':
    print("Mining Claude Code transcripts for command invocations...")
    print(f"Transcript root: {cct.projects_root()}")
    print(f"Archive root: {ARCHIVE_ROOT}")
    print()

    result = mine_transcripts()

    # Write JSON output
    output_file = r"C:\development\ai-agent-kit\.worktrees\commands-usage-opportunities\docs\reports\_stage-a-command-usage.json"
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2)

    print(f"[OK] JSON output written: {output_file}")
    print()
    print(f"Corpus: {result['corpus']['project_dirs']} project dirs, " +
          f"{result['corpus']['jsonl_files']} JSONL files, " +
          f"{result['corpus']['sessions_scanned']} sessions scanned")
    print(f"Totals: {result['totals']['distinct_commands']} distinct commands, " +
          f"{result['totals']['total_union_invocations']} union invocations")
