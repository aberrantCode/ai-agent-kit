---
name: shell-migration-skip-taxonomy
category: DevOps & Tooling
description: Use when deciding whether a shell script can safely be migrated to source a centralized helper library — classifies scripts by execution context (repo checkout vs. remote payload vs. on-host) to identify the categories that must be permanently skipped or only partially migrated.
status: active
version: 2026-07-05
---

# Shell Migration Skip Taxonomy

## When to use

Alongside the shell-helper-migration skill, before migrating any script to source a shared helper module. Some scripts cannot source a sibling file at all, and migrating them anyway silently breaks the deployment. Use this taxonomy to classify a script before touching it.

## Method

1. **Apply the core test: WHERE does the script body physically execute?** Not whether it uses SSH. An orchestrator that runs `ssh host 'some-command'` from the repo checkout is fine to migrate; a script body that is itself piped into a remote shell (`ssh target 'bash -s' < script.sh`, or `scp`'d to `/tmp` and run there) cannot source a workstation-side sibling, because the remote shell never inherits the caller's filesystem layout.
2. **Check against the seven skip categories:**
   - **`#!/bin/sh` on-host** — scripts running as root on target systems (e.g. a NAS) where `${BASH_SOURCE[0]}` is empty under `dash` and no `phases/` sibling directory exists remotely.
   - **remote-ssh-payload** — helper definitions inside `<<'REMOTE' ... REMOTE` heredocs fed to `ssh 'bash -s'`; these execute in a fresh remote shell that never inherits workstation functions, so the remote must define its own helpers.
   - **journald-captured-logger** — a script with a single custom-timestamp stdout logger feeding `journalctl` directly, not piped through a shell command.
   - **stdout-report-renderer** — status helpers that share a colour palette and output stream with retained custom siblings (e.g. custom `err()`/`row()` functions that must stay paired with the helpers being replaced).
   - **partial-palette** — a script whose colour variables span two different layers (status helpers vs. instructional/user-facing content) where only one half actually overlaps with the centralized module.
   - **exit-code-only-divergence** — rare: a file with several migratable helpers but one `die()` that exits with a non-1 code. Migrate the majority; redefine just that one `die()` locally after sourcing rather than skipping the whole file.
   - **no self-location anchor** — a script that assumes its runtime location is not the repo (e.g. `cd $HOME/repos/AC_OPBTA` instead of `REPO_ROOT=$(dirname "$0")/..`) cannot reliably locate a sibling file to source.
3. **For heredoc payloads specifically, use a line-order test.** Helper definitions are only in-scope for deletion/migration if they execute workstation-side *before* the first `bash -s <<REMOTE` heredoc-opener line. Compare the helper-def line number N to the first heredoc-opener line: if N < first-heredoc, it's in-scope for migration; otherwise skip. Non-ASCII glyphs inside heredocs are safe as-is (they render on the remote host, not the workstation) — do not strip them during migration.
4. **Also treat custom stdout sentinels as permanent skips** — e.g. a machine-readable marker like `DEPLOY_FAIL` that downstream tooling parses. Migrating the surrounding helpers must not touch or reformat these sentinel lines.
5. **When a script fails any single category check, skip the whole file** — unless it's the exit-code-only-divergence case, which allows a documented partial migration (migrate the compatible helpers, keep the one divergent helper local).

## Gotchas

- Don't infer skip status from "uses SSH" — that's necessary but not sufficient. The determinant is execution location of the body, not the presence of a network call.
- A file can look migratable (has all the canonical helper names) and still be a hard skip because of *where* it runs, not *what* it contains.
- Discovering any skip category mid-migration means stopping and re-classifying that file — don't assume the rest of a batch shares the same classification just because the filenames look similar.

## Diagram

[View diagram](diagram.html)
