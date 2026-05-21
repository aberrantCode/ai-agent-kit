# Fingerprint Algorithm

The `docs/what-next.md` cache is trusted as long as the **fingerprint set** still matches the repo.
A fingerprint is a SHA-256 hash over a small, carefully chosen list of files.

## What to fingerprint

Include these files (only if they exist):

| File / glob                               | Why it's fingerprinted                           |
|-------------------------------------------|--------------------------------------------------|
| `backlog.md`                              | Primary task store — any edit invalidates plans  |
| `backlog-archive.md`                      | Closure state of completed tasks                 |
| `docs/features/*.md`                      | Feature specs (project-manager framework)        |
| `docs/plans/*.md`                         | Plan files (project-manager framework)           |
| `docs/INITIAL_PROMPT.md`                  | Source of truth for product intent               |
| `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `*.csproj`, `Gemfile`, `composer.json` | Stack signals; a change means new deps or renames |
| `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json` | Monorepo structure                            |
| `.github/ISSUE_TEMPLATE/*`                | Team PM convention changes                       |
| `README.md`                               | Top-level intent changes                         |
| `CHANGELOG.md`                            | Release/direction cues                           |

Do **not** fingerprint the whole codebase — that would invalidate the cache on every code change.
The cache is about *project-management context*, not line-of-code drift.

## How to hash

For each file:

1. Read the contents as UTF-8.
2. Normalise line endings to `\n`.
3. For lockfiles (`package-lock.json`, `yarn.lock`, `poetry.lock`, etc.) — skip entirely. They
   churn too often.
4. SHA-256 the normalised bytes.
5. Store as `<relative-path>: <hex-digest>`.

## Staleness check

```
for each entry in cache.fingerprints:
  if file missing:         stale
  if recompute != stored:  stale

for each currently-tracked file not in cache.fingerprints:
  stale (new file appeared that the cache didn't know about)
```

If stale, AskUserQuestion whether to refresh now or proceed with the cached context (the user may
want a quick read). Default to refresh.

## Why not mtime?

File mtimes reset on `git clone`, `git reset`, Docker COPY, CI restores, and many editor saves that
don't actually change content. Content hashes are authoritative; mtimes are noise.
