---
name: comment-harvesting
description: >
  Domain expertise for harvesting comments and threads from a YouTube video using yt-dlp.
  Sub-skill of `youtube-extraction`. Use when the parent skill needs comments as a primary
  source for filenames, repo URLs, corrections, and creator follow-ups that don't appear
  in the video itself.
---

# Comment Harvesting

Sub-skill of `youtube-extraction`. You receive `url` and `<basename>`.

## Goal

Place comments at:
```
docs/youtube-extraction/<basename>/comments.json
```

…as a flat JSON array preserving thread parentage so downstream consumers can
reconstruct conversations.

## Why comments matter for extraction

For a tutorial-style video, the comment section is the second draft of the
content. Common high-value patterns:

- The creator pinning a comment with the GitHub repo URL.
- The creator replying with corrections ("at 4:30 that should be `Pool` not `Map`").
- Viewers asking for clarification on a file path that the speaker glossed over,
  with the creator replying with the canonical name.
- Long thoughtful threads that act as an FAQ — frequently they call out the
  exact filenames of the artifacts shown in the video.

Skipping comments costs more extraction depth than skipping any other source
besides the transcript itself. Always harvest them.

## Primary command

```powershell
yt-dlp --skip-download --write-comments `
  -o "docs/youtube-extraction/<basename>/yt.%(ext)s" `
  "<url>"
Move-Item -Force docs/youtube-extraction/<basename>/yt.comments.json `
  docs/youtube-extraction/<basename>/comments.json
```

`--write-comments` recurses into reply threads by default. For very popular
videos (10k+ comments) this can be slow — pass `--max-comments 1000,all,100`
to cap top-level/replies/per-thread; surface the cap to the user via
`AskUserQuestion` if you need to diverge from the default.

## Post-processing

The raw `comments.json` is a list of dictionaries with at least these fields:

- `id`, `parent` (or `null` for top-level)
- `author`, `author_is_uploader`
- `text`
- `timestamp` or `time_text`
- `like_count`, `is_pinned`

Before handing off to downstream sub-skills, surface a short
`comments_summary.json` next to it with the high-value subset:

```json
{
  "creator_comments": [ … all comments where author_is_uploader=true … ],
  "pinned": [ … comments where is_pinned=true … ],
  "top_liked": [ … top 10 comments by like_count … ],
  "filename_mentions": [ … comments whose text matches /\b[\w./-]+\.(py|ts|tsx|js|jsx|md|json|yaml|yml|toml|sh|ps1|sql|html|css)\b/ … ],
  "url_mentions": [ … comments whose text contains a URL … ]
}
```

`filename_mentions` and `url_mentions` are the buckets `file-reconstruction`
will lean on most heavily.

## Edge cases

- **Comments disabled.** `comments.json` will be an empty array. That is fine —
  return without error and let downstream sub-skills proceed without comment
  evidence.
- **Live-chat replays.** For premieres and live VODs, `--write-comments` may
  also pull live-chat. Filter those out by checking `comment_type` if present —
  live-chat is noisier and rarely contains canonical filenames.
- **Spam.** Don't bother filtering spam at this stage. Downstream consumers
  match on filename/URL patterns that spam rarely satisfies.

## Idempotence

If `comments.json` already exists for `<basename>`, only re-fetch on explicit
refresh request (comment threads on older videos are mostly stable). Append a
new `comments.<ISO-date>.json` instead of overwriting if the user does want a
fresh pull.
