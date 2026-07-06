# Pipeline-State Schema

Conventions for the columns in your driving CSV.

## Per-phase columns

Each phase that does per-row work owns two columns:

```
<phase>_done            : 'true' | 'false'    (string, default 'false')
<phase>_done_by_model   : string              (default '')
```

Plus result columns specific to the phase, named with the phase prefix where it makes sense for clarity (e.g., `score`, `score_reasoning`, `category`).

## Why two columns and not one boolean

The `_done_by_model` field gives you cheap per-row provenance. It costs you 8 bytes per row in the CSV and saves you significant pain when:

1. You change the model (mistral → llama3) and want to re-process only the rows the old model handled.
2. You change the prompt and want to re-process everything that the LLM did but not the deterministic regex rows.
3. You audit downstream — "where did this score come from?"

To re-process a subset:

```powershell
$rows = Import-Csv 'data/pipeline.csv'
foreach ($r in $rows) {
    if ($r.scored_by_model -eq 'ollama+mistral') {
        $r.scored = 'false'
        $r.score = ''
        $r.scored_by_model = ''
    }
}
$rows | Export-Csv 'data/pipeline.csv' -NoTypeInformation -Encoding utf8
```

Then re-run the score phase. The state machine handles the rest.

## Why string `'true'`/`'false'` instead of bool

CSV is stringly-typed. Different languages serialize bools differently (`True` in Python, `true` in JS, `TRUE` in older Excel exports). Stick with the lowercase string and your state machine has no impedance mismatch — every consumer sees the same value.

The cost is `if ($row.done -eq 'true')` instead of `if ($row.done)`. Worth it.

## Default values

For an unprocessed row that just came out of discovery:

| Column | Default |
|---|---|
| `<phase>_done` | `'false'` |
| `<phase>_done_by_model` | `''` |
| Result columns (score, category, etc.) | `''` |
| ID columns | the actual ID |
| Foreign keys | the actual key |

Don't use `null`, `N/A`, or `unknown` — that's three different states for the same thing. Empty string everywhere.

## Worked example: github-repos pipeline

```
repo_id, episode_id, video_id,
repo_url, repo_readme_url, repo_owner,
repo_date_first_seen, repo_date_last_commit,
description_downloaded, readme_downloaded,
readme_analyzed, readme_analyzed_by_model,
scored, score, scored_by_model
```

Phases:
- **extract** (writes new rows; doesn't have its own per-row state column because it produces rows)
- **download description** → flips `description_downloaded`
- **download readme** → flips `readme_downloaded`, fills `repo_readme_url`
- **analyze readme** → flips `readme_analyzed`, fills `readme_analyzed_by_model`
- **score** → flips `scored`, fills `score`, `scored_by_model`

Each phase has its own eligibility rule:

| Phase | Eligibility |
|---|---|
| download readme | `readme_downloaded = false` |
| analyze readme | `readme_downloaded = true AND readme_analyzed = false` |
| score | `readme_analyzed = true AND scored = false` |

The prerequisite chain falls out naturally from these eligibility rules.

## Two CSVs vs. one

If your corpus has two scales (episodes vs. repos in this case), use two CSVs:

- `episodes.csv` — coarse-grained, one row per video. Has its own state columns for episode-level work.
- `github-repos.csv` — fine-grained, one row per (episode, repo). Has its own state columns for repo-level work.

Foreign-key the fine-grained CSV back to the coarse-grained one (`episode_id`, `video_id`).

When the same logical entity (a repo URL) appears in N rows, the state columns on those N rows track the SAME state — they all flip together when the artifact lands. See `pipeline-state-schema.md` § per-row vs per-artifact dedup.

## Adding a new phase later

Don't migrate the schema. Just add columns:

```powershell
$rows = Import-Csv 'data/pipeline.csv'
$updated = foreach ($r in $rows) {
    [PSCustomObject]([ordered]@{
        # ... existing columns ...
        new_phase_done = 'false'
        new_phase_done_by_model = ''
    })
}
$updated | Export-Csv 'data/pipeline.csv' -NoTypeInformation -Encoding utf8
```

Then write the phase function. State columns at default mean the phase will pick everything up on first run.
