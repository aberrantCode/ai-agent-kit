---
name: analyze-parallelism
description: >
  Read-only future parallelism analysis for project-manager plans. Preserves serial execution by
  default and only identifies guarded batches with explicit file scope metadata.
---

# Analyze Parallelism

This command is read-only. It does not spawn workers and does not enable parallel execution by
itself. Serial `/continue-tasks` remains the default.

## Required Metadata

A task can be considered for a parallel batch only when the task file or plan row includes:

- `parallel: true`
- `depends_on_tasks`: local task ids that must be done first
- `conflicts_with`: task ids that must not run in the same batch
- `files_allowed`: owned file globs
- `files_shared`: shared file globs requiring coordination

Tasks missing file scope metadata are serial-only.

## Analysis Rules

1. Run `references/scripts/pm-validate.ps1` if present.
2. Read approved plans and active tasks.
3. Exclude blocked, stale, malformed, in-progress, or verification-pending work.
4. Exclude tasks whose feature dependencies are incomplete.
5. Group only `todo` tasks whose `depends_on_tasks` are done.
6. Reject a batch if two tasks own the same `files_allowed` path, if either names the other in
   `conflicts_with`, or if a shared file has no single owner.
7. Require isolated git worktrees for any future execution batch.
8. Require one batch-level verification/merge checkpoint before plan rows are marked `done`.

## Output

Return:

- Tasks that are serial-only and why
- Candidate parallel batches
- File ownership table
- Shared-file coordination notes
- Required verification/merge checkpoint

Do not recommend parallel execution unless every task in the batch has explicit file scope and no
detected conflicts.
