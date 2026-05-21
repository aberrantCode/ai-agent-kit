---
name: file-reconstruction
description: >
  Domain expertise for stitching multi-frame OCR evidence into canonical source files on
  disk — without duplicating overlapping lines — and for placing each file at a sensible
  path inside the calling repo. Sub-skill of `youtube-extraction`.
---

# File Reconstruction

Sub-skill of `youtube-extraction`. This is the heart of the `recreate-files`
operation. You receive `frames.recognition.json`, the `transcript.md`, the
`comments.json` (and its `comments_summary.json`), and the calling repo's
existing folder structure.

## Goal

For each unique `file_path` across the recognition catalogue, produce one
real file inside the calling repo whose contents reflect what the creator
showed in the video — without duplicated lines, with gaps filled from
secondary evidence where possible.

## Why this is non-trivial

A scrolling IDE pane produces N frames where consecutive frames share most
of their visible lines. Naive concatenation writes each line N times. Even
non-naive concatenation can miss lines that briefly flicker past too fast
for any single frame to capture cleanly.

The robust approach: treat each frame's visible-line block as a string and
merge consecutive frames using **longest common subsequence (LCS)** at line
granularity. Then cross-check the merged result against quoted snippets in
the transcript and comments.

## Algorithm

For each unique `file_path`:

1. **Collect.** Pull every recognition entry with that `file_path`. Sort by
   `t` (frame timestamp ascending).
2. **Initialise.** Start with the lines from the first frame's `content`
   (split on `\n`).
3. **For each subsequent frame:**
   a. Compute the LCS at line granularity between (current accumulated
      content) and (this frame's `content`).
   b. Identify the **overlap region** — the contiguous tail of accumulated
      content that matches a contiguous head of the new frame.
   c. Append everything in the new frame's `content` after that overlap.
   d. If the new frame has a `line_range` and the gutter says it starts at
      a line number *higher* than where you'd expect from concatenation,
      that's a scroll past unread lines — emit a `// TODO: lines X-Y not
      captured` placeholder and try to fill it from transcript quotes.
4. **Cross-check with transcript.** Search `transcript.md` for verbatim
   quotes (3+ words from the file) — if the transcript has a phrase that
   does not appear in your reconstruction but contextually belongs (e.g.
   matches a function name in the file), surface this as a discrepancy
   rather than silently adding it.
5. **Cross-check with comments.** Comments occasionally paste full canonical
   versions of files the creator promised in the video. If
   `comments_summary.json.creator_comments` contains a code block whose
   first non-blank line matches your file's signature (function name, class
   name, top-of-file imports), prefer the comment's version and note this
   in `EXTRACTION.md`.
6. **Trim placeholders.** If a `// TODO` placeholder is the last line of the
   file, drop it — the creator likely just didn't scroll to the end.

## Line-level LCS — concrete pattern

When merging frame A into accumulated buffer B:

```text
B (accumulated, last 6 lines):    A (new frame, first 6 lines):
  function verify(t) {              function verify(t) {
    const claims =                    const claims =
      jwt.decode(t)                     jwt.decode(t)
    if (!claims) {                    if (!claims) {
      throw new Error(                  throw new Error(
        "invalid"                         "invalid"
                                        )
                                      }
```

The overlap is 6 lines. Append only A's 7th and 8th lines onto B. Net
effect: lines that appear in both frames appear once in the output.

For low-confidence frames (`confidence < 0.8`) demand a stricter overlap —
require ≥ 4 contiguous matching lines before trusting the alignment. For
high-confidence frames, 2 lines of overlap is enough.

## Choosing the on-disk path

The `file_path` from recognition is what the creator showed (e.g. `src/auth/jwt.ts`).
Your job is to map that into the calling repo:

1. **If the calling repo already has a matching folder structure**, use it.
   E.g. if the repo has `src/`, write to `src/auth/jwt.ts`. Match the deepest
   common prefix.
2. **If the video's path is repo-rooted but the calling repo lacks the
   parent folder**, create the parent folder. The creator's intent is to
   establish that structure.
3. **If the video shows only a bare filename** (`jwt.ts` with no parent),
   place the file based on the creator's spoken context (transcript) or
   comments. If neither resolves the location, ask the user via
   `AskUserQuestion`:
   - Question: "Where should `jwt.ts` go in this repo?"
   - Options: "Under `src/`", "Under repo root", "Custom path (specify below)"
4. **If the calling repo already has a file at the target path with
   different content**, do not overwrite blindly. Use `AskUserQuestion`:
   - Question: "`src/auth/jwt.ts` already exists with different content.
     Overwrite, append, or save side-by-side?"
   - Options: "Overwrite", "Save as `src/auth/jwt.from-youtube.ts`", "Skip"

## Idempotence

Re-running `recreate-files` on the same video must not corrupt prior work.
Before writing each file, hash its current on-disk contents (if any) and
the new reconstructed contents. Identical hash → skip silently. Different
→ trigger the conflict prompt above.

## Catalogue output

After all files are written, write a manifest at:
```
docs/youtube-extraction/<basename>/files/_manifest.json
```

…with one entry per reconstructed file:

```json
[
  {
    "path": "src/auth/jwt.ts",
    "lines": 84,
    "frames_used": ["frame_00042.jpg", "frame_00045.jpg", "frame_00048.jpg"],
    "transcript_evidence": ["[03:07]", "[03:21]"],
    "comment_evidence": ["pinned creator comment"],
    "gaps": [],
    "overall_confidence": 0.91
  }
]
```

The manifest is the input to `extraction-reporting` — it does not need to
walk recognition state itself.

## What to surface back

- Path to `files/` directory
- Path to `_manifest.json`
- Count of files written, count skipped due to conflicts
