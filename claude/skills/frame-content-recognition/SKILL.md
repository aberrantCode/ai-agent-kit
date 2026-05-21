---
name: frame-content-recognition
description: >
  Domain expertise for visually inspecting extracted video frames to identify which ones
  show file content (IDE panes, terminal cat, slides, READMEs) and capture path, language,
  and visible line ranges. Sub-skill of `youtube-extraction`.
---

# Frame Content Recognition

Sub-skill of `youtube-extraction`. You receive the path to a frames directory
plus its `frames.index.json`, and produce a structured catalogue of file-content
sightings across the video.

## Goal

Write `frames.recognition.json` next to the frames index:

```json
[
  {
    "frame": "frame_00042.jpg",
    "t": 187.4,
    "kind": "ide",
    "file_path": "src/auth/jwt.ts",
    "language": "typescript",
    "line_range": [12, 47],
    "content": "…\nexport function verify(token: string): Claims {\n…",
    "confidence": 0.92,
    "evidence": ["editor tab text reads 'jwt.ts'", "VSCode chrome visible", "line numbers visible in gutter"]
  },
  …
]
```

Each entry represents one frame's worth of evidence about one file. Multiple
frames will reference the same `file_path` — that's expected and is what the
next sub-skill stitches together.

## Inspecting frames

You inspect frames using your own multimodal vision capability. Drive it with
the `Read` tool against each frame image. For long videos this is the most
expensive step in the pipeline — be selective.

### Selection heuristic

Don't process every frame. Process:

1. Every scene-change frame from `frame-extraction` (these are flagged in the
   ffmpeg `showinfo` output, or you can detect them by checking which frame
   indexes are non-monotonic with respect to the 1-fps anchors).
2. Every frame whose nearest transcript line contains a hint that file content
   is being shown — keywords: `file`, `let me show you`, `here's`, `cat`,
   `paste`, `we're going to write`, `look at`, paths matching
   `[\w./-]+\.(py|ts|tsx|js|jsx|md|json|yaml|yml|toml|sh|ps1|sql|html|css)`.

This typically reduces the OCR set by 70–90% on tutorial videos with talking-
head segments.

### Per-frame interrogation

For each selected frame, ask yourself:

1. **Is file content visible at all?** A talking-head shot with no shared
   screen → `kind: "talking_head"` and skip the rest. A whiteboard → `kind:
   "whiteboard"`. A diagram-only slide → `kind: "diagram"`.
2. **What kind of viewer is shown?** Common kinds:
   - `ide` — VSCode, JetBrains, Vim, Emacs. Look for tabs, gutter line numbers,
     status bar.
   - `terminal_cat` — `cat`, `less`, `bat` output. Look for prompt lines and
     monospace header.
   - `terminal_editor` — vim/nano in a terminal. Look for status line.
   - `slide` — a code block on a presentation slide. Look for fixed background
     and centred layout.
   - `readme` — a markdown file rendered in a browser/IDE preview. Look for
     headings and rendered links.
3. **What is the file path?** Sources, in priority order:
   - Editor tab title
   - Title bar / window chrome
   - Terminal command preceding the content (`cat src/auth.ts`)
   - On-screen breadcrumbs
   - File-tree pane highlight
4. **What is the language?** Infer from extension first; fall back to syntax
   highlighting cues if the path is missing.
5. **What lines are visible?** If the gutter shows line numbers, capture the
   `[start, end]` range exactly. Otherwise use `[null, null]` and let
   `file-reconstruction` figure out ordering from frame timestamps.
6. **What is the content?** Transcribe what you can see, line-for-line. Don't
   guess at lines that are clipped by the viewport — leave `…` placeholders so
   the next sub-skill knows to fill those gaps from neighbouring frames.

## Pitfalls — what NOT to do

- **Don't infer code that wasn't shown.** If a closing brace is off-screen,
  do not synthesise it. Leave the partial state and let `file-reconstruction`
  reconcile across frames.
- **Don't mix files.** A multi-pane IDE shot (split editor) shows two files —
  emit two entries, one per pane. Crop your attention to one pane at a time.
- **Don't over-trust OCR for similar glyphs.** When you're unsure between
  `l` / `1` / `I`, drop the line's confidence and add an evidence note —
  `file-reconstruction` will use the transcript to disambiguate.

## Confidence scoring

Use these floors:

| Confidence | Meaning |
|-----------:|---------|
| 0.95+ | Clear IDE shot, file path visible in tab, gutter line numbers visible, glyphs unambiguous. |
| 0.8–0.95 | Path inferred from terminal command or window title, content readable. |
| 0.6–0.8 | Path guessed from context (slide deck without explicit filename), partial content. |
| < 0.6 | Note the sighting but flag it; downstream may discard. |

## Idempotence

If `frames.recognition.json` exists, do not re-run unless `frames/` itself
changed. This step is expensive — avoid redoing it.

## What to surface back

- Path to `frames.recognition.json`
- Count of distinct `file_path` values detected
- Coverage stats: how many frames contained recognised file content vs. talking-head
