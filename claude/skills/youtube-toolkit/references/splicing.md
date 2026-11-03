# Splicing clips from several split videos

`scripts/splice_clips.py` builds one video from the chapter-section clips of several
videos. Typical inputs are the `sections/` folders written by `cut-chapters.sh`
(see SKILL.md step 4).

## Flags

| Flag | Meaning |
|---|---|
| `--group LABEL=DIR` | Required, repeatable. `DIR` is a folder of `.mp4` clips, or a download folder that contains `sections/`. Flag order is the interleave order. |
| `--out FILE` | Required. Output mp4; parent folders are created. Overwritten on every run. |
| `--exclude SUBSTR` | Repeatable. Drop clips whose filename contains the substring (case-insensitive). Default: exclude nothing. |
| `--pick N` / `--pick LABEL=N` | Random subset: `N` per group, or per group by label. A bare `N` is the default for groups without their own. Default: all eligible clips. |
| `--seed N` | Make the random pick reproducible. |
| `--random-order` | Keep picks in the order drawn instead of re-sorting to source order. |
| `--width/--height/--fps` | Normalisation target. Default 1920x1080 at 30 fps. |
| `--dry-run` | Print the sequence and the ffmpeg command; run nothing. |

## Behaviour

- Round-robin: `A1, B1, C1, A2, B2, C2, ...`. Unequal groups: the longer group's
  leftovers are appended in order.
- Clip names are matched on the **filename**, so pick exclusions from the chapter titles
  in `chapters.txt` (`01-get-ready.mp4` is excluded by `--exclude get-ready`).
- Every input is scaled and padded to the target size (aspect ratio kept), set to SAR 1,
  resampled to a constant fps, and its audio resampled to 48 kHz stereo, then joined with
  ffmpeg's concat filter in a single libx264 / AAC re-encode (CRF 20, `veryfast`).

## Caveats

- Every clip needs an audio stream (the concat filter pairs video and audio). Clips cut
  from a silent source will fail; add a silent track first.
- Re-encoding is CPU-heavy for long mixes; use `--dry-run` to check the plan first.
- Output is a derived file; do not splice into a folder that is also a `--group`
  (it would be picked up as a clip on the next run).

## Example: mixed workout

```bash
python scripts/splice_clips.py \
  --group abs=abs-workout --group bicep=bicep-workout --group shoulder=full-shoulder \
  --exclude get-ready --exclude intro --exclude wall-sit \
  --pick abs=4 --pick bicep=3 --pick shoulder=3 --seed 7 \
  --out mix/spliced-workout.mp4
```
