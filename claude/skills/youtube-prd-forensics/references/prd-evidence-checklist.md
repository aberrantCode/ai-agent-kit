# PRD Evidence Checklist

Completion gate for `youtube-prd-forensics`. One verifiable item per workflow
step. Do not consider the skill's run complete until every box is checked —
each item must be confirmable by looking at a file on disk, not by memory of
having "done something like that."

## 1. Prepare output locations

- [ ] `docs/` exists at the repo root and is writable.
- [ ] `docs/images/screenshots/` exists (created even if empty at this point).

## 2. Download and persist the source video

- [ ] `docs/<project>_reference_1080p.<ext>` exists and is a valid, playable
      video file (non-zero size, correct container for `<ext>`).
- [ ] The filename's `<project>` basename matches the one used consistently
      in later steps (transcript, keyframes, PRD).

## 3. Extract YouTube page artifacts

- [ ] `docs/youtube_metadata.json` exists and contains the video's title,
      channel/creator, publish date, and duration.
- [ ] `docs/youtube_description.txt` exists and contains the video description.
- [ ] `docs/youtube_comments.json` exists (even if the comment list is empty
      because comments are disabled — the file must still be present).

## 4. Generate transcript

- [ ] `docs/transcript_notes.md` exists.
- [ ] Every entry in `docs/transcript_notes.md` carries a timestamp that can
      be cross-referenced against the source video.
- [ ] If the YouTube-provided subtitles were unavailable, confirm the
      transcript was generated from the local video file instead (not
      skipped).

## 5. Extract keyframes and build an index

- [ ] A keyframe working directory (for example
      `docs/images/video_frames_5s/`) contains one frame image approximately
      every 5 seconds of video runtime.
- [ ] An index file in that directory maps each frame filename to its
      timestamp.
- [ ] The index's last timestamp is within one interval of the video's total
      duration (no large unexplained gap at the end).

## 6. Analyze keyframes and transcript together

- [ ] Each derived requirement cites at least one timestamp and, where a
      visual claim is made, the keyframe that supports it.
- [ ] Observed facts (what the video literally shows) are distinguished from
      inferred requirements (what the team concluded should be built).

## 7. Persist high-resolution screenshots

- [ ] `docs/images/screenshots/` contains the specific screenshots referenced
      by `docs/PRD.md` — not the entire keyframe set.
- [ ] Screenshot filenames use descriptive, numerically prefixed names (for
      example `01_hud_overview.jpg`) matching what the PRD references.

## 8. Update or write `docs/PRD.md`

- [ ] `docs/PRD.md` includes source metadata (video URL, title, creator,
      publish date, duration, description summary, notable comments).
- [ ] Every requirement section maps a feature/behavior to an explicit
      timestamp.
- [ ] Every major requirement section embeds at least one screenshot from
      `docs/images/screenshots/`.
- [ ] If an existing PRD was edited rather than written fresh, a
      modification/change-summary table was appended.

## 9. Delete keyframes, retain final artifacts

- [ ] The keyframe working directory from step 5 (for example
      `docs/images/video_frames_5s/`) no longer exists.
- [ ] All required persisted artifacts listed in the skill's "Required
      Persisted Artifacts" section are still present after cleanup:
      the downloaded video, `docs/transcript_notes.md`, `docs/PRD.md`,
      `docs/images/screenshots/*`, `docs/youtube_metadata.json`,
      `docs/youtube_description.txt`, `docs/youtube_comments.json`.
