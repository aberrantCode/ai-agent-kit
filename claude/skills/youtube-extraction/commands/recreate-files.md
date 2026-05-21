---
description: Inspect a YouTube video's frames, transcript, description, and comments to find files the creator showed or discussed, then recreate each one on disk in the calling repo with a markdown report describing the result.
---

Apply the `youtube-extraction` skill and execute its `recreate-files` operation.

Parse the user's invocation for two parameters:
- A YouTube URL (any youtube.com or youtu.be link)
- A free-text request describing what to extract — for this command the default
  is "All files shown or discussed in the video", but accept narrowing focus
  (e.g. "only python files", "the docker-compose stanza", "config files in src/").

If either parameter is missing from the invocation, do not proceed — use the
`AskUserQuestion` tool to elicit the missing values exactly as the parent
skill's "Eliciting missing parameters" section prescribes. Never inline-print
a free-text question.

Once both parameters are resolved, follow the parent skill's `recreate-files`
operation step-by-step: video-acquisition → transcript-acquisition →
comment-harvesting → frame-extraction → frame-content-recognition →
file-reconstruction → extraction-reporting.
