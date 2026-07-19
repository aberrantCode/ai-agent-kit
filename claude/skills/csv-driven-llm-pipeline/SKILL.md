---
name: csv-driven-llm-pipeline
category: AI & LLM
description: Build a stateful, resumable batch pipeline driven by CSV files with per-row pipeline-state columns. Use whenever the user wants to iterate over a corpus and do per-row work that may take time, hit external APIs, call an LLM, or need restart-resilience — even if they don't say "pipeline". Triggers on phrases like "process all the X", "for each row do Y", "analyze the corpus", "batch enrich", "add a column tracking whether...", "extract X from Y for every Z", or any task requiring eligibility filtering, idempotent re-runs, rate-limit awareness, or downstream-resumable state. Covers schema design, phase-by-phase execution, deterministic discovery, rate-limited HTTP fetching, iterative LLM prompt engineering with A/B testing, and PowerShell pitfalls.
---

# CSV-Driven LLM Pipeline

A pattern for building **stateful, resumable, phase-by-phase batch pipelines** over a corpus that lives in CSV files. Optimized for jobs that take minutes-to-hours, mix HTTP fetching with LLM calls, need to survive interruptions, and may run multiple times against an evolving dataset.

This skill captures battle-tested conventions for:

- **Schema** — pipeline-state columns and the CSV layout that makes resume-trivial.
- **Driver** — phase-by-phase script structure with eligibility filtering, dry-run, and limits.
- **Discovery** — how new rows enter the system from an upstream source.
- **Per-row dedup vs. per-artifact dedup** — when the same logical entity has N rows.
- **HTTP rate limiting** — request delay, `Retry-After`, circuit breaker.
- **LLM prompt engineering** — the v0 → v1 → v2 layering method with CSV-reset A/B testing.
- **PowerShell gotchas** — syntax pitfalls that cost hours to debug.

---

## When to invoke

You're building a job that:

1. Iterates over a corpus (rows in a CSV, items on a YouTube channel, repos, papers, customers, products).
2. Does per-item work that takes seconds to minutes — HTTP fetches, LLM calls, file parsing, scraping.
3. Should be **idempotent** (re-running picks up where it left off) and **resumable** (a crash or `Ctrl-C` doesn't lose progress).
4. May span multiple **phases** (download → enrich → classify → score) where later phases depend on earlier ones.
5. May iterate over the same dataset many times (the user keeps adding new sources or changing prompts).

If only one of these applies, a normal one-shot script is fine. The skill earns its keep at three or more.

---

## The pattern

### 1. Schema: pipeline-state columns

Each phase that mutates per-row state gets two columns in the driving CSV:

| Column | Type | Meaning |
|---|---|---|
| `<phase>_done` | `'true'` / `'false'` (string, lowercase) | Has this phase completed for this row? |
| `<phase>_done_by_model` | string, blank by default | What did the work? `regex`, `ollama+mistral`, `openai+gpt-4o`, `manual`, etc. — purely informational. |

Plus result columns specific to each phase. Example for a repo-analysis pipeline:

```
repo_id, repo_url, ...,
description_downloaded, readme_downloaded,
readme_analyzed, readme_analyzed_by_model,
scored, score, scored_by_model
```

**Why two columns per phase, not one boolean?** The model field gives you per-row provenance — when you switch models or prompts, you can re-run only the affected rows by resetting `_done` and re-running. Auditing is also free.

**Why string `'true'`/`'false'` and not a real bool?** CSVs are stringly-typed. Sticking with strings avoids language-specific bool serialization mismatches (`True` vs `true` vs `1`).

Default value for an unprocessed row: `<phase>_done = 'false'`, `<phase>_done_by_model = ''`.

### 2. Driver: phase-by-phase execution

The script accepts a `-Phase` parameter (`[string[]]`) listing which phases to run. Default is all. Each phase is a function:

```
function Invoke-<Phase>Phase {
    if (-not $run<Phase>) { return }
    # 1. Guard: required input file present?
    # 2. Eligibility: rows where <phase>_done = false (and prerequisite columns true)
    # 3. Apply -Limit if set
    # 4. For each eligible row:
    #      do the work
    #      flip the state columns
    #      write CSV (per-row persistence — see below)
}
```

Drive with:

```powershell
Invoke-DiscoveryPhase
Invoke-ExtractPhase
Invoke-EnrichPhase
Invoke-ClassifyPhase
Invoke-ScorePhase
```

Per-row CSV writes are the core of the resume guarantee. A crash mid-loop loses at most one row of work.

### 3. Discovery (how new rows enter)

Every pipeline needs an entry point that creates new CSV rows. Common shapes:

- **Sync from an upstream CSV** — diff `upstream.csv` against `episodes.csv` by an ID column; append missing rows with state columns at default.
- **Scrape an external source** — `yt-dlp`, `gh api`, web scrape — into the upstream CSV first, let the diff path handle the rest.
- **User-supplied IDs** — read from stdin or a flat file.

Always make discovery **idempotent**: re-running with no new items must be a no-op. Use the unique-id-set membership check.

### 4. Per-row vs. per-artifact dedup

Often the same logical entity (a repo URL, a customer email, a paper DOI) appears in N rows because of denormalization. The artifact (downloaded README, scraped HTML, LLM analysis) should be stored ONCE and the state columns flipped on ALL N rows.

Pattern:

- Disk path: `data/<entity-type>/<slug>/` (e.g., `data/repos/<owner>__<repo>/`).
- CSV update: when the artifact lands, group all rows by `<entity_url>` and flip all of them.

This avoids re-downloading the same README every time it's referenced.

### 5. Rate-limited HTTP

Three knobs cover 95% of real-world rate limiting:

- **`-RequestDelayMs <int>`** — sleep between requests. 250ms = ~240 req/min, well under abuse thresholds for most public APIs and CDNs.
- **`-MaxThrottleStreak <int>`** — abort the phase after N consecutive throttle responses. State is per-row durable, so resuming later is trivial.
- **Honor `Retry-After`** on 429 responses. Default to 60s if the header is missing.

Use `Invoke-WebRequest -SkipHttpErrorCheck` (PS 7+) so the response object is always available — you can inspect `StatusCode` and `Headers['Retry-After']` without try/catch noise.

Return a typed status hashtable from your fetch helper (`{status: 'ok' | 'throttle' | 'not_found' | 'error'}`) and `switch` on it in the loop. This separates "failed permanently" from "try again later" cleanly.

See `references/rate-limited-fetch.ps1` for a drop-in helper.

### 6. LLM prompt engineering

For classification or extraction prompts, layer three techniques in order:

- **v1 — Decision rules** — taxonomy with one-line definitions and 2-3 exemplars per category, plus a numbered list of decision rules.
- **v2 — Worked examples + anti-patterns** — 5 short README-hint → JSON-output pairs covering known traps, plus a list of "common wrong call → correct answer".
- **Add a `<field>_reasoning` field to the output JSON** — forces the model to cite a rule or anti-pattern. Surfaces hallucinations as audit signal.

Lower temperature to `0.1` for classification. Mistral and similar small models default to over-classifying as the most "popular" category (often AI/ML); the rules + anti-patterns block this.

A/B testing methodology:

1. Save the current prompt to `prompt-v0.md` (or commit it).
2. Reset the state columns for ~10 representative rows so they get re-processed.
3. Run with `-Limit 10`.
4. Diff the output JSONs against v0.
5. Tabulate accuracy and commit.

See `references/prompt-iteration.md` for the full method.

### 7. PowerShell gotchas

These cost hours if you don't know about them:

- **`[string[]]` for comma-separated parameters.** `[string]$Phase` will collapse `-Phase a,b,c` to a space-joined `'a b c'` single string.
- **`${var}:` in interpolation.** PS parses `$url:` as a scope/drive prefix. Wrap with `${}`.
- **Avoid `$profile`, `$matches`, `$_` as locals.** They're automatic variables.
- **Triple backticks in here-strings.** PS double-quoted strings treat `` ` `` as an escape. Assign `$fence = '` + `'` + `'` to a variable and interpolate.
- **`-SkipHttpErrorCheck`** beats try/catch around `Invoke-WebRequest` when you need the response on non-2xx.
- **`Export-Csv` with `[PSCustomObject][ordered]@{}`** preserves column order. Plain `@{}` does not.

Full list in `references/pwsh-gotchas.md`.

---

## Workflow when invoking this skill

When the user wants to build a pipeline that fits the pattern:

1. **Ask 4 design questions** before writing code (use AskUserQuestion):
   - **Pipeline mode** — per-row-all-phases, phase-by-phase-all-rows, or `-Phase` flag-controlled?
   - **Discovery** — does the script auto-create new rows from an upstream source, or only process existing ones?
   - **Extraction method** — deterministic (regex, parser) or LLM-based? Mixed?
   - **Legacy state** — is there an existing cache file or schema to migrate or retire?

2. **Lay down the schema first** in the CSV. State columns at default values. Add columns even if you don't have data yet — `false` and empty strings are valid placeholders.

3. **Implement phases incrementally** — discovery first, then phase 1, then run it on `-Limit 1` to verify, then phase 2, and so on. Don't write all phases up front.

4. **Per-row CSV write** is non-negotiable. Even if the phase is "fast enough" today, it won't be in 6 months when the corpus 10×s.

5. **For HTTP phases, add the rate-limit triplet** (`-RequestDelayMs`, circuit breaker, `Retry-After`) BEFORE the bulk run, not after. Adding it later means losing data to throttling once.

6. **For LLM phases, run `-Limit 10` first**, eyeball the output, then iterate the prompt before the bulk run. The prompt-iteration recipe is cheap; the bulk run is expensive.

7. **Commit after each phase completes** — separate PR per phase keeps reviewable. The data CSVs go in commits too; their diffs are the audit trail.

---

## Files in this skill

- `references/pipeline-state-schema.md` — full column convention with examples.
- `references/phase-driver-template.ps1` — minimal working PowerShell skeleton.
- `references/rate-limited-fetch.ps1` — drop-in HTTP helper with the typed-status pattern.
- `references/prompt-iteration.md` — v0 → v1 → v2 method + A/B harness recipe.
- `references/pwsh-gotchas.md` — full syntax pitfall list with examples.
- `assets/v2-classification-prompt.md` — battle-tested classification prompt template.

Read whichever you need; SKILL.md is sufficient for the high-level decision.

---

## Origin

Extracted from the github-awesome project (PRs #14 - #24): a 14-phase rebuild of a YouTube-channel analysis pipeline that processes ~160 episodes and ~2700 GitHub repos with idempotent discovery, rate-limited GitHub fetches, and ollama-driven classification.

## Diagram

[View diagram](diagram.html)
