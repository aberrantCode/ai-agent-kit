---
name: content-aware-file-renaming
description: >
  Use when renaming files into a structured naming formula based on their contents —
  especially batches of downloaded documents (statements, invoices, tax forms, receipts,
  contracts, confirmations), generic-named files (document.pdf, document (1).pdf,
  IMG_*.jpg, scan*.pdf, untitled.*), bulk extracts from broker/bank portals or email
  attachments, or zip archives that must be extracted before processing. Triggers when
  the existing filename does not carry the document's identity and the file's content
  must be inspected to determine who, what, where, and when. The canonical naming
  formula is `%who% - %what% - %where% - %when% - %extra%`. Always prompt the user via
  AskUserQuestion only — never as plain text.
---

# Content-Aware File Renaming

Rename a batch of files (PDFs, images, scans, archive contents) by reading what's
inside each one and applying the user's structured naming formula. The formula values
must come from the file's content, not its filename or filesystem timestamps.

**Critical rule (non-negotiable):** Every prompt to the user MUST go through the
`AskUserQuestion` tool. Never print a question as plain text and wait. `AskUserQuestion`
is a deferred tool in Claude Code — call `ToolSearch` with `query: "select:AskUserQuestion"`
once per session before the first use.

---

## The Naming Formula

```
%who% - %what% - %where% - %when% - %extra%
```

| Segment   | Required | Meaning                                                                                        | Examples |
|-----------|----------|------------------------------------------------------------------------------------------------|----------|
| `%who%`   | yes      | Person or organization that **sent / published / originated** the file                         | `Pershing`, `Northwestern Mutual`, `IRS`, `Hilton`, `Acme Corp`, `Jane Smith` |
| `%what%`  | yes      | Type / category / item-name. May include an optional **subtype** when needed to disambiguate   | `Monthly Statement`, `Annual Statement`, `1099 Tax and Year-End Statement`, `Trade Confirmation`, `Hotel Receipt`, `Contract Signed` |
| `%where%` | optional | Location the file applies to — city/country for travel, redacted account/contract # for finance, room/site/property name | `xxxxx6099` (redacted account), `xxxxx7183` (redacted contract), `Paris FR`, `Site B`, `1600 Pennsylvania Ave` |
| `%when%`  | yes      | The date the file is **applicable to** (NOT file mtime/ctime). Granularity matches the doc    | `2024` (annual), `2024-09` (monthly), `2024-09-13` (single-event), `2024-Q3` (quarterly) |
| `%extra%` | optional | Disambiguator when everything else matches — version, sequence #, "corrected", short hash      | `corrected`, `v2`, `original`, `seq-21`, `ticket-AAPL` |

**Separator:** ` - ` (space, hyphen, space). Each segment is optional only where the
table allows. Skipped optional segments collapse: there are no double-separators in the
final filename. Example with `%where%` and `%extra%` omitted:

```
Pershing - Monthly Statement - 2024-09.pdf
```

Example with all segments present:

```
Pershing - Trade Confirmation - xxxxx6099 - 2024-09-13 - ticket-COPX.pdf
```

---

## When to Use

Trigger this skill when **any** of these conditions hold:

- The user mentions the formula tokens (`%who%`, `%what%`, `%where%`, `%when%`, `%extra%`)
  or asks to "rename" / "organize" / "tidy up" a batch of downloaded documents.
- Filenames are generic and uninformative: `document.pdf`, `document (N).pdf`,
  `IMG_*.jpg`, `scan*.pdf`, `untitled.*`, `Receipt.pdf`, etc.
- The user provides one or more zip archives whose contents need renaming.
- The user wants files moved into a target subdirectory based on their content.

**Do NOT use this skill for:**

- A single file rename where the user already knows the exact target name.
- Renaming based purely on existing filename patterns (no content inspection needed).
- Renaming source code, config, or other files where the filename IS the identity.

---

## Workflow

The work is structured in six phases. Move through them in order; do not skip ahead.

### Phase 1 — Verify the source set

Before reading any contents, lock in **exactly which files** are in scope.

1. Use `AskUserQuestion` to confirm or fill any of these that aren't already specified:
   - **Source directory** — where the files live now.
   - **Target directory** — where renamed files should land (often a new subfolder).
   - **Date window** — e.g., "everything from 5/1/2026" or "downloaded in the past 3
     weeks". Convert relative dates to absolute dates (`Today's date is YYYY-MM-DD`
     comes from system context).
   - **File types** — typically `.pdf` and `.zip`, but can include `.jpg`, `.heic`,
     `.docx`, `.eml`, `.csv`, etc.
2. List the matching files using `Glob` (for patterns) and a directory walk filtered by
   `LastWriteTime` (for date ranges). Show the user a short summary —
   `<n> matching files, oldest mtime <X>, newest mtime <Y>` — via `AskUserQuestion` to
   confirm the set looks right before doing any work.
3. If zips are in scope, **extract each into a temporary working folder** under the
   source directory (e.g., `_rename_inspect/<zipname>/`). Treat extracted files exactly
   like loose files for the rest of the workflow.

### Phase 2 — Pre-analyze a representative sample

Reading every file's full content is expensive. Sample 3–7 files spanning the breadth
of the batch (different sizes, different filename hints if any) and inspect them:

| File type            | Inspection tool                                           |
|----------------------|-----------------------------------------------------------|
| `.pdf`               | `pdftotext -layout -f 1 -l 2 <file> -` (Poppler)          |
| `.jpg / .heic / .png`| `exiftool -DateTimeOriginal -GPSPosition <file>`          |
| `.docx`              | `python -c "from docx import Document; ..."` or unzip + read `word/document.xml` |
| `.eml`               | `Read` directly — headers carry From/Date/Subject         |
| `.csv / .txt`        | `Read` first 50 lines                                     |

From the samples, build a mental model:

- **Distinct issuers (%who%)** — How many? Is there more than one organization mixed
  into the batch? (Common surprise: a "brokerage" download includes statements from a
  related but separate institution.)
- **Distinct document types (%what%)** — list them. Note which need a subtype (e.g.,
  "Statement" alone is ambiguous when both monthly and annual exist).
- **Date granularity** — annual? monthly? per-event? Different doc types in the same
  batch can have different granularities, and that's fine.
- **Where signal** — is there an account number, contract number, location, or
  property reference inside? How is it formatted? Should it be redacted?

### Phase 3 — Confirm formula nuances with the user

Use `AskUserQuestion` (mandatory — never plain text) to lock in decisions about how
the formula maps to **this specific batch**. Ask only what the samples leave ambiguous.
Pick from these question templates as needed; do not ask all of them every time.

- **Issuer naming**: when the same entity has multiple legal names (e.g., "BNY
  Pershing", "Pershing LLC", "Pershing"), which form do you want for `%who%`?
- **Account/contract masking**: should `%where%` show the full account number, or
  redacted (e.g., `xxxxx6099` for the last 4)? What's the masking convention?
- **Subtype usage**: when two doc types share a base name (e.g., "Annual Statement"
  vs "Monthly Statement"), should `%what%` carry the subtype as part of the same
  segment, or only when needed to disambiguate?
- **Date format per type**: confirm `%when%` granularity per document type — e.g.,
  `YYYY` for tax forms, `YYYY-MM` for monthly statements, `YYYY-MM-DD` for
  per-transaction confirmations.
- **Non-target files**: if the batch contains files that don't match the user's
  intent (marketing PDFs, "how to" guides, instructional cover sheets), should they
  be skipped, kept under a different `%who%`, or discarded?
- **Out-of-scope issuers**: if other organizations' files appear, should they be
  renamed under their own `%who%`, separated into a sibling folder, or skipped?
- **Duplicates**: how aggressive should dedup be? (See Phase 5.)

When asking, present 2–4 concrete options with descriptions — never open-ended
free-text questions. The user can always pick "Other" to override.

### Phase 4 — Classify every file

Now read content from every file in the batch (not just the sample). For each file,
extract the four core values:

```
{ issuer, doc_type, where_value, when_value }
```

Use a script — do not do this by hand for batches over ~10 files. PowerShell or Python
both work; Python with `subprocess` calling `pdftotext`/`exiftool` is usually cleanest.
Save the per-file results to a JSON manifest next to the source files (e.g.,
`_rename_inspect/classify_manifest.json`).

For each file, also record:
- `original_path`, `original_name`, `size_bytes`
- `sha256` (for later verification, not for dedup — see below)
- `classify_status`: `ok`, `skip` (intentionally excluded), or `unknown` (parsing
  failed — needs manual review or a refined regex)
- `page1_excerpt` (first 600 chars) — invaluable when debugging `unknown` cases

If `classify_status` for any file is `unknown`, refine the classifier and re-run.
**Never proceed with `unknown` files** — silent misclassification is worse than a slow
loop. Iterate the script: peek at one `unknown` excerpt, add the missing pattern,
re-run, repeat until 100% are `ok` or `skip`.

### Phase 5 — Build a dedup-and-rename plan (no destructive actions yet)

**Dedup by logical identity, not by byte hash.** Many portals re-render the same
document on every download with timestamps embedded — two PDFs of the same statement
will have different SHA256s but identical content. Group records by the tuple:

```
(issuer, %what%, %where%, %when%)   — i.e., everything but %extra%
```

For each group:
1. **Pick the canonical source** — prefer files extracted from the user's most
   structured source (e.g., a properly-named entry inside a zip) over generic-named
   loose copies. Tie-break by smallest file size (Pershing-style portals sometimes
   bloat re-downloads with extra metadata).
2. **Build the planned filename** — `%who% - %what% - %where% - %when%.pdf` (or with
   `%extra%` appended if collisions remain after dedup).
3. **Detect cross-group filename collisions** — if two distinct logical documents
   would resolve to the same target name, append `(1)`, `(2)`, ... or use `%extra%`.

Write the plan to `plan.json` plus a human-readable `plan_summary.txt` showing:
- Source-file count → unique-document count, deduplicates dropped
- Breakdown by `%who%` → `%where%` → planned filenames
- Skipped files (and why)
- Unclassified files (must be empty before proceeding)

**Show this plan to the user via `AskUserQuestion`** with options:
- Proceed with move + delete originals
- Proceed with move but keep originals (dry-run-ish)
- Show me a few more examples first (loop back to refine)

### Phase 6 — Execute: copy, verify, then delete

The destructive sequence MUST be **copy → verify → delete**, in that order. Do not
move files in one step.

1. **Copy** each canonical source to the target directory under its planned name. Use
   `shutil.copy2` (preserves mtime) or PowerShell `Copy-Item`. Do not delete the
   source yet.
2. **Verify** every copy by re-hashing the destination and comparing to the recorded
   `sha256` of the source. **Abort immediately on the first mismatch** — leave both
   the source and any partial destination in place and tell the user.
3. **Delete originals** only after all copies verify:
   - All loose source files matching the original date/type filter
   - All source zip files (their contents now live in the target dir)
   - The temporary `_rename_inspect/` working folder

Print a final summary: target file count, total bytes, breakdown by `%who%`. Spot-check
that the source directory no longer contains stragglers from the batch.

---

## Field-extraction patterns (quick reference)

These are starting points for the classifier — adjust per the actual content you see.

### PDF financial documents

| Doc type                             | Header signal                                                         | Date source                                            | Granularity     |
|--------------------------------------|------------------------------------------------------------------------|--------------------------------------------------------|-----------------|
| Monthly account statement            | Date range header + "Portfolio at a Glance" / "Account Summary"        | end of date range                                      | `YYYY-MM`       |
| Quarterly statement                  | Quarter header / "Q1 YYYY"                                            | quarter end                                            | `YYYY-Qn`       |
| Annual / year-end statement          | "Year-End Summary" / "December YYYY"                                  | year                                                   | `YYYY`          |
| Trade / transaction confirmation     | "Confirmation" header + "Process Date: <date>" / "Trade Date: <date>" | Process Date (full)                                    | `YYYY-MM-DD`    |
| 1099 (Tax Year-End Statement)        | "<YYYY> TAX and YEAR-END STATEMENT"                                   | the printed tax year                                   | `YYYY`          |
| 1099 Pending Notice                  | "<YYYY> PENDING 1099 NOTICE"                                          | the printed tax year                                   | `YYYY`          |
| 1099 Tax Information Statement       | "<YYYY> YOUR TAX INFORMATION STATEMENT"                               | the printed tax year                                   | `YYYY`          |
| ACH / wire transfer notice           | "Automated Clearing House (ACH) Transfer" / "Wire Transfer Notice"   | transaction date in body                               | `YYYY-MM-DD`    |
| Annuity confirmation statement       | "Income Annuity / Confirmation Statement / Contract Date"             | Contract Date                                          | `YYYY-MM-DD`    |
| Annuity summary statement            | "Income Annuity / Summary Statement / For the Period: X through Y"   | period end year                                        | `YYYY`          |
| Check issue notification             | "Check Issue Notification" + Date column                              | issue date                                             | `YYYY-MM-DD`    |

### Account/contract masking

When `%where%` represents an account or contract number, mask all but the last 4 digits.
Match the user's existing convention if one is in evidence (e.g., they previously used
`xxxxx6099` — keep the same number of `x` characters even when it doesn't match the
exact length of the redacted prefix).

### Travel and expense documents

| Doc type                | Header signal                              | `%where%` source              | Date source         |
|-------------------------|--------------------------------------------|-------------------------------|---------------------|
| Hotel folio / receipt   | Property name + "Folio" / "Statement"      | property city/country         | check-out date      |
| Airline receipt         | Carrier + "E-Ticket Receipt"               | origin/destination IATA codes | first leg date      |
| Restaurant receipt      | Merchant name + total                      | merchant city                 | transaction date    |
| Rideshare receipt       | "Uber" / "Lyft" + ride summary             | pickup city                   | ride date           |
| Conference invoice      | Event name + "Registration Invoice"        | event city                    | event start date    |

### Image files

For photos / scans / screenshots:

```bash
exiftool -s -DateTimeOriginal -GPSLatitude -GPSLongitude -ImageDescription <file>
```

`%when%` from `DateTimeOriginal` (full date — usually `YYYY-MM-DD`). `%where%` from
GPS coordinates reverse-geocoded if the user wants location-based names; otherwise
omit. `%who%` and `%what%` need user input — images rarely self-identify.

---

## AskUserQuestion patterns

These are the question templates this skill uses most. Always prefer 2–4 concrete
options with clear descriptions over open-ended prompts. Add "Other" only when truly
needed (the harness adds it implicitly).

```jsonc
// Lock in the source set
{
  "question": "I found <N> files matching <pattern> in <dir> with mtime between <X> and <Y>. Process all of them?",
  "header": "Source set",
  "options": [
    { "label": "Yes — all <N> files", "description": "Treat the full match as the batch" },
    { "label": "Refine the filter",   "description": "Tighten by date, file type, or pattern" },
    { "label": "Show me a sample first", "description": "List 5 files so I can spot-check" }
  ]
}
```

```jsonc
// Lock in %where% convention when an account/contract is present
{
  "question": "Files reference account numbers like <example>. How should %where% be formatted?",
  "header": "Account masking",
  "options": [
    { "label": "Last 4 with xxxxx prefix", "description": "e.g., xxxxx6099 — hides full account, keeps last 4 visible" },
    { "label": "Full number", "description": "e.g., B40-076099 — leak risk if the file is shared" },
    { "label": "Skip %where%", "description": "Omit the where segment for these files" }
  ]
}
```

```jsonc
// Final confirmation before destructive action
{
  "question": "Plan: <N> source files → <M> unique docs into <target>/. Originals will be deleted after hash-verified copies. Proceed?",
  "header": "Execute plan",
  "options": [
    { "label": "Yes — move + delete originals",  "description": "Copy, verify by SHA256, then delete originals and the temp folder" },
    { "label": "Yes — move but keep originals",  "description": "Copy with new names but leave originals in place for spot-checking" },
    { "label": "No — show me sample mappings",   "description": "Print 3–5 old → new examples first" }
  ]
}
```

---

## Common mistakes

| Mistake                                                      | What goes wrong                                                                                                 | Fix                                                                                                  |
|--------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| Using `LastWriteTime` for `%when%`                          | Statements reflect the period they cover, not when you downloaded them — a 2024 1099 downloaded in 2026 ends up with `2026-05-01` | Always extract `%when%` from PDF content (header, period, statement date)                            |
| Deduping by SHA256                                          | Portal-rendered PDFs are byte-different on every download, so hash-dedup keeps all of them                      | Dedup by `(issuer, type, where, when)` tuple                                                          |
| Moving files in one step (rename without intermediate copy) | An interrupted move leaves files in a partial state that's hard to recover                                       | `copy → SHA256-verify → delete` always                                                                |
| Asking the user as plain text                               | The harness highlights only `AskUserQuestion` prompts; plain-text questions get skipped or answered wrongly      | Every prompt is a tool call. No exceptions.                                                          |
| Assuming all files in a batch are from the same issuer      | A "brokerage download" can mix Pershing statements with Northwestern Mutual annuity notices — same `who%` is wrong | Inspect samples first; ask the user how to handle out-of-scope issuers                              |
| Skipping the `unknown` files in the manifest                | Whatever the classifier missed gets silently dropped or misnamed                                                  | Iterate the classifier until every file is `ok` or `skip`. Treat `unknown` as a build failure.       |
| Reading every file's full text                              | 100+ PDFs × full extraction = slow                                                                              | First page (sometimes first two) is enough for header-based classifiers                              |
| Hardcoding date format for the whole batch                  | Trade confirmations need `YYYY-MM-DD`, monthly statements need `YYYY-MM`, tax forms need `YYYY`                  | Granularity is per doc type — confirm with the user during Phase 3 and apply per-type in the script  |
| Not deleting the temp working folder                        | `_rename_inspect/` accumulates over time and clutters the source directory                                       | Final cleanup step removes the working folder                                                        |

---

## Files this skill creates while running

These are temporary; clean them up in Phase 6.

```
<source-dir>/_rename_inspect/
  ├── <zipname>/                  # extracted zip contents, one folder per zip
  ├── classify_manifest.json      # per-file extracted fields + sha256 + page1 excerpt
  ├── plan.json                   # full move plan
  ├── plan_summary.txt            # human-readable summary
  ├── classify.py                 # the classifier script (kept for reproducibility)
  ├── build_plan.py               # the dedup/plan builder
  └── execute_plan.py             # the move-and-verify runner
```

The scripts can be Python (preferred for regex-heavy classification) or PowerShell.
Keep them small, idempotent, and re-runnable — if the classifier missed a pattern, you
should be able to edit it and re-run without re-extracting zips.

---

## Iron rule

**No prompt to the user that is not an `AskUserQuestion` tool call.** This is the
single non-negotiable constraint of this skill. If you find yourself about to write a
question into your response text and stop, that is the wrong move — call
`AskUserQuestion` instead. Always.
