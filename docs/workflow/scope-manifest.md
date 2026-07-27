---
product_scope: ["src/**", "api/**", "components/**", "app/**", "packages/*/src/**"]
chore_safe: ["docs/**", "scripts/**", ".github/**", "*.md", "*.config.*"]
---

# Scope Manifest

This file is the machine-enforced boundary between the **chore lane** and the **feature lane**
(see `docs/reports/2026-07-16-pm-lifecycle-redesign.review.md` §2.5). `scripts/guard-pm-flow.ps1`
reads it — via `docs/workflow/scope-manifest.md`, its fixed path — every time a staged commit's
active task has `feature: chore-*`.

## How the guard uses this file

For a chore-lane commit, the guard classifies every staged source file against the two glob lists
above:

- **`product_scope` hit → hard FAIL.** Behaviour-bearing code cannot ride the lightweight chore
  lane, no matter what the task's `scope_confirmed` flag says. Route the change through
  `/groom → /add-feature` (spec + plan) instead.
- **`chore_safe` hit → allowed.** Docs, scripts, CI config, and generic config files are safe by
  definition.
- **Neither list matches (unclassified) → allowed only if the authorizing chore task has
  `scope_confirmed: true`.** An operator explicitly acknowledged the file is out-of-manifest but
  still safe. `scope_confirmed` can unblock an *unclassified* file; it can never override a
  `product_scope` hit.

If this file is missing, the chore lane is inert — the guard fails closed for every chore task
until a manifest exists.

## Frozen at promotion — this file's own edits are a normal reviewed diff

Every chore task freezes an `authz_snapshot.manifest_sha` (the sha256 of this file) at the moment
it is promoted from the backlog. The guard re-hashes this file on every chore commit; if the live
hash no longer matches the frozen `manifest_sha`, the task is **stale** and fails closed until it
is re-groomed (re-frozen against the current manifest).

Because of that snapshot, **editing this file must never ride in the same commit as a chore task
that depends on it** — the guard's same-commit self-authorization block rejects any commit that
both stages `docs/workflow/scope-manifest.md` and relies on an active chore task. Widening or
narrowing `product_scope` / `chore_safe` is scope-changing policy work: it goes through its own
commit, reviewed like any other change, with no active chore task riding along.

## Editing guidance

- Keep both lists as glob arrays (`**` = any depth, `*` = one path segment, `?` = one character).
- Prefer directory-rooted globs (`src/**`) over broad top-level wildcards — precision here is what
  keeps the chore lane both fast and safe.
- When adding a new top-level source directory to the project, add it to `product_scope` in the
  same commit that introduces it (not as a drive-by edit riding a chore task).
