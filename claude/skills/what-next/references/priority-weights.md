# Priority Weights

Pending tasks are scored with a weighted sum. Higher score = more urgent. The top three scores are
shown to the user; the rest stay in the backlog.

## Default weight table

| # | Signal                                                    |  Weight |
|---|-----------------------------------------------------------|--------:|
| 1 | Task blocks one or more other tasks                       |    +40  |
| 2 | Task tagged `security` or `SEC-` prefix                   |    +35  |
| 3 | Task tagged `build-breaking`                              |    +30  |
| 4 | Task targets code with failing tests                       |    +25  |
| 5 | Task is already `in-progress`                             |    +20  |
| 6 | Explicit `priority: p1`                                   |    +15  |
| 7 | Explicit `priority: p2`                                   |     +5  |
| 8 | Task age (days since added), log-scaled: `round(log2(days+1) * 3)` | varies |
| 9 | Task description is very short (<20 chars — likely stub)  |     -3  |
|10 | Explicit `priority: p3`                                   |     -5  |
|11 | **Implicitly blocked** — another task's `{blocks: ...}` tag names this ID | **-15** |
|12 | **Stale** — task references a file path that no longer exists | **-25** |

Signals are additive. A task can accumulate multiple positive signals.

### Implicit blocking

`{blocks: ...}` tags on other tasks mean the listed IDs **cannot start yet**. Example:

```
- [ ] AUTH-001: Add password reset flow {priority: p1} {blocks: AUTH-002}
- [ ] AUTH-002: Add 2FA support {priority: p2}
```

AUTH-002 is implicitly blocked by AUTH-001 even though AUTH-002 has no tag of its own. Apply `-15`
to AUTH-002 so it doesn't surface in the top-three alongside its blocker. When AUTH-001 flips to
`- [x]`, the `-15` goes away automatically.

This is computed at scoring time by building a reverse index: `blocked[id] = [blockers...]`. A
task is implicitly blocked iff any of its blockers is still `- [ ]`.

### Stale

A task is **stale** if its description references a file path that doesn't exist on disk. Example:

```
- [ ] LEGACY-001: Refactor src/old/thing.ts
```

…when `src/old/thing.ts` has been deleted. Apply `-25` so these tasks don't block the top-three,
but *never auto-close them* — only the user can decide whether to retire or rewrite them. The
`-25` is bigger than the p3 penalty because a stale task is *worse than low priority* — it's
undefined.

## Reading the tags

Tags can appear anywhere on the task line:

```
- [ ] AUTH-004: Refactor login middleware {priority: p1} {security} {blocks: AUTH-005, UI-012}
```

Or in a frontmatter block at the top of `backlog.md`:

```yaml
---
AUTH-004:
  priority: p1
  tags: [security]
  blocks: [AUTH-005, UI-012]
---
```

Either format is accepted. Prefer the inline `{...}` tag style when creating new items since it
keeps the file diff-friendly.

## Worked example

Three pending tasks:

| ID       | Description                           | Tags                               |
|----------|---------------------------------------|------------------------------------|
| AUTH-004 | Refactor login middleware             | p1, security, blocks 2 others      |
| UI-011   | Fix button alignment on mobile        | p2                                 |
| DOC-002  | Update README with install steps      | p3, age: 14 days                   |

Scores:

- **AUTH-004**: +40 (blocks others) +35 (security) +15 (p1) = **90**
- **UI-011**: +5 (p2) = **5**
- **DOC-002**: -5 (p3) + 12 (14-day age bonus: `round(log2(15) * 3)`) = **7**

Top three: AUTH-004 (90), DOC-002 (7), UI-011 (5).

Note that age can push an older p3 above a fresh p2 — intentional. Old tasks deserve attention.

### Worked example 2 — implicit blocking

Given a five-task backlog:

```
- [ ] AUTH-001: Add password reset flow {priority: p1} {blocks: AUTH-002}
- [ ] AUTH-002: Add 2FA support {priority: p2}
- [ ] UI-001:   Fix button alignment on mobile {priority: p2}
- [ ] API-001:  Migrate orders endpoint to v2 {priority: p3}
- [ ] SEC-001:  Audit JWT secret rotation {security}
```

Scores:

- **AUTH-001**: +40 (blocks AUTH-002) +15 (p1) = **55**
- **SEC-001**: +35 (security) = **35**
- **UI-001**: +5 (p2) = **5**
- **AUTH-002**: +5 (p2) **-15 (implicitly blocked by AUTH-001)** = **-10**
- **API-001**: -5 (p3) = **-5**

Top three: AUTH-001 (55), SEC-001 (35), UI-001 (5). AUTH-002 correctly drops below the line —
working on it now would either block on AUTH-001 or produce merge conflicts.

## Tuning

Users can override any weight by adding a `priority_weights:` block to `docs/what-next.md`:

```yaml
priority_weights:
  blocks_others: 60     # we care *a lot* about unblocking
  security: 50
  p1: 10                # but p1 alone isn't as loud as security
```

Missing keys fall back to defaults. The skill reads this block every run — no need to invalidate
the cache when tuning weights.

## Tie-breakers

When two tasks score identically, break ties in this order:

1. Explicit priority (p1 > p2 > p3)
2. Fewer outgoing dependencies
3. Shorter description (roughly: smaller scope, faster win)
4. Alphabetical by ID
