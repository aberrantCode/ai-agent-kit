---
name: extraction-reporting
description: >
  Domain expertise for generating the final markdown report that summarises a YouTube
  extraction operation — files reconstructed, evidence trail, gaps, and follow-ups.
  Sub-skill of `youtube-extraction`.
---

# Extraction Reporting

Sub-skill of `youtube-extraction`. You receive every artifact produced by
upstream sub-skills and produce one human-readable report.

## Goal

Write `docs/youtube-extraction/<basename>/EXTRACTION.md`. This is the
hand-off document — the user reads it to understand what was extracted,
how confident the extraction is, and what is still missing.

## Required structure

Use this exact section order, even when a section is empty (write
"(none)" rather than omitting). Empty sections still telegraph that the
extraction step ran and found nothing.

```markdown
# Extraction Report — <video title>

## Source
- URL: <url>
- Channel: <channel name>
- Published: <ISO date>
- Duration: <hh:mm:ss>
- Local video: `docs/youtube-extraction/<basename>/video.<ext>`
- Resolution captured: <e.g. 1080p>

## Request
The extraction request the user provided (verbatim).

## Files Reconstructed

| Path | Lines | Confidence | Frames | Transcript refs |
|------|------:|-----------:|-------:|-----------------|
| `src/auth/jwt.ts` | 84 | 0.91 | 5 | [03:07], [03:21] |
| … | … | … | … | … |

For each file with confidence < 0.8 or with `gaps`, add a short prose note
beneath the table calling out what's uncertain.

## Evidence Map

A per-file mapping back to the video. For each reconstructed file:

### `src/auth/jwt.ts`
- First shown: [03:04]
- Last shown: [03:31]
- Source kind: ide (VSCode)
- Stitched from: frame_00042.jpg, frame_00045.jpg, frame_00048.jpg
- Cross-checked against: transcript [03:07], [03:21]; pinned creator comment
- Notes: line 47 was inferred from transcript ("we throw with the message
  invalid"); flag if the user wants to verify.

## Transcript Highlights
A handful of timestamped quotes that aren't tied to a single file but
inform overall context (architecture, design decisions, "we'll come back
to X").

## Comments Worth Reading
Pinned comments, creator replies, and comments that supplied filename or
URL evidence. Link by author + timestamp; quote the salient snippet.

## Gaps and Follow-ups
- Files referenced in the transcript or comments that were never shown
  on screen and could not be reconstructed.
- Files that were shown but had so few visible lines that confidence is
  too low to commit (manifest filtered them out).
- Resolution / OCR caveats from upstream sub-skills.

## Screenshots
Embed selected full-frame screenshots that anchor the report. Use
`docs/youtube-extraction/<basename>/screenshots/` and copy chosen frames
in from the `frames/` working directory before it is deleted. Name them
descriptively with numeric prefixes (`01_jwt_module_overview.jpg`).

## Reproduction
The exact thin command and parameters used:
```text
/recreate-files <url> "<request>"
```
…so the user can re-run.
```

## Cross-references rather than duplication

Do not paste reconstructed file contents into the report. Link to them by
relative path. The report is the *index*; the files are the artifact.

## Choose screenshots with intent

Aim for 5–10 screenshots, not the full frame dump. Pick:

- One frame per major file showing the IDE chrome and tab title (proves
  attribution).
- Any frame that captures a full-screen path (`README.md` rendered, repo
  tree visible) — useful to anchor the file layout.
- Any frame that supplied evidence the report flags as uncertain.

Move chosen frames from `frames/` to `screenshots/` *before* the parent
operation deletes `frames/`.

## Tone

- Factual, not promotional. The user asked for an extraction, not a review.
- Distinguish observed (from a frame or a verbatim transcript quote) from
  inferred (from context). When uncertain, say so.
- Lead each file's evidence section with the strongest source. Frames before
  transcript before comments before "I assumed".

## Idempotence

If `EXTRACTION.md` already exists for `<basename>`, never overwrite blindly.
Diff the new report against the previous and:

- If they're materially identical, leave the existing file.
- If they differ, archive the previous to `EXTRACTION.<ISO-date>.md` and
  write the new file.

## What to surface back

- Path to `EXTRACTION.md`
- Counts: files reconstructed, screenshots embedded, gaps flagged
