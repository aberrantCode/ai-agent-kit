# Area Inference

Task IDs in `backlog.md` are **area-scoped** — `AUTH-001`, `UI-002`, `PAY-003`. This file defines
how the skill converts folder names into 2–4-letter prefixes.

## Discovery

Scan these locations for candidate area folders:

1. Top-level subdirectories of the repo root (excluding hidden, `node_modules`, `dist`, etc.).
2. `src/*` if a `src/` folder exists.
3. `apps/*` and `packages/*` in monorepos.
4. `services/*` if a `services/` folder exists.

Each candidate folder becomes a potential area.

## Prefix generation rules

Apply these in order:

1. **Common aliases** (always use these if the folder matches, case-insensitive):

   | Folder name                  | Prefix |
   |------------------------------|--------|
   | `auth`, `authentication`     | AUTH   |
   | `ui`, `frontend`, `client`   | UI     |
   | `api`, `server`, `backend`   | API    |
   | `db`, `database`, `models`   | DB     |
   | `payments`, `billing`, `pay` | PAY    |
   | `admin`                      | ADMIN  |
   | `core`                       | CORE   |
   | `utils`, `shared`, `common`  | UTIL   |
   | `docs`, `documentation`      | DOC    |
   | `infra`, `infrastructure`    | INFRA  |
   | `mobile`, `ios`, `android`   | MOBILE |
   | `test`, `tests`, `e2e`       | TEST   |

2. **Acronym extraction** — if the folder name is multi-word (kebab- or snake- or camel-cased),
   take the first letter of each word: `user-profile` → `UP`, `notification-center` → `NC`,
   `OrderManagement` → `OM`. If the result is < 2 letters, pad with the next consonant from the
   first word.

3. **Truncate** — single-word folder names: take the first 3–4 uppercased letters.
   `reporting` → `REPO`, `insights` → `INSI`.

4. **Collision handling** — if two folders would map to the same prefix, extend one or both to
   4 letters or disambiguate with the parent folder: `apps/web` and `packages/web` might become
   `AWEB` and `PWEB`.

## Special prefixes (reserved)

| Prefix | Meaning                                                  |
|--------|----------------------------------------------------------|
| SEC    | Security findings (from security-reviewer agent)         |
| ARCH   | Architecture findings (from architect agent)             |
| TEST   | Test-coverage findings (from tdd-guide agent)            |
| DOC    | Documentation work                                       |
| GEN    | Fallback when the repo is too small to have clear areas  |

These are always used by the code-analysis flow regardless of folder layout — do not remap them.

## Confirmation

On the first run for a new repo, AskUserQuestion to show the inferred area map:

```
Question: "I've inferred the following area prefixes from your repo structure. Look right?"
Options:
  - "Yes, these look good"
  - "Let me adjust some of them"
  - "Use GEN for everything — the repo is too small to partition"
```

If the user picks "adjust", present each prefix one at a time (via another AskUserQuestion round)
so they can rename. Store the final map in `docs/what-next.md` under `areas:`.

On subsequent runs, the cached `areas:` block is authoritative — do not re-infer.

## Numbering

Within each area, IDs are sequential starting at 001, zero-padded to three digits. IDs are never
reused: when a task is completed and archived, its ID is gone forever. Use `backlog-archive.md` as
the authoritative list of used IDs to avoid collisions.
