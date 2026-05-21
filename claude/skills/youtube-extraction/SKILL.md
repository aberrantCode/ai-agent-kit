---
name: youtube-extraction
description: >
  Reconstruct locally the solution depicted in a YouTube video — files, configurations,
  commands, transcripts, and supporting artifacts. Use whenever the user wants to extract,
  recreate, mirror, scrape, harvest, or rebuild content from a YouTube video, even if they
  don't say "extract" — phrases like "recreate the project from this video", "pull the
  files out of this tutorial", "rebuild what they showed", or "scrape this YouTube
  walkthrough" all qualify. Each thin command in this bundle requires a YouTube URL and a
  free-text request describing what to extract; if either is missing, this skill MUST use
  the AskUserQuestion tool to elicit the missing parameters before proceeding.
---

# YouTube Extraction

You are the domain expert for reconstructing locally the solution depicted in a YouTube
video. Your job is to turn a video into real artifacts on disk: source files, transcripts,
comments, screenshots, and a markdown report describing what was extracted and how it maps
back to the video.

This skill is a thin orchestrator. The deep domain knowledge lives in sub-skills under
`sub-skills/`. Each thin command in `commands/` invokes this skill and names a single
operation; this skill chains the right sub-skills to fulfil that operation.

---

## Parameter Contract

Every operation in this skill requires two inputs:

| Parameter | Description |
|-----------|-------------|
| `url`     | A YouTube video URL (`https://www.youtube.com/watch?v=…` or short form). |
| `request` | Free-text description of what within the video should be extracted (e.g. "all source files shown in the IDE", "the docker-compose stanza around 4:20", "the slash-command files the speaker pastes"). |

### Eliciting missing parameters

If the invocation does not provide both `url` and `request`, you MUST use the
`AskUserQuestion` tool to prompt for whatever is missing — never inline-print a
free-text question.

- **URL missing:** ask one question with header `YouTube URL` whose options are
  "Paste the URL" (Other) and "Cancel". Treat the user's free-text answer as the
  URL and validate it matches a YouTube host before proceeding.
- **Request missing:** ask one question with header `What to extract` whose options
  reflect the calling thin command's defaults (for `/recreate-files` the recommended
  default is "All files shown or discussed in the video"). Provide a "Custom focus"
  Other slot. The user's selection is the `request`.
- **Both missing:** ask both in a single `AskUserQuestion` call (one question for
  URL, one for the extraction request).

If a thin command has a sensible default for `request` (e.g. `/recreate-files`
defaults to "all files"), state the default in your prompt rather than blocking on
an answer the user can shrug at. Always block on a missing `url`.

---

## Workspace Layout

All extracted artifacts live under a single directory derived from the video's
basename. Use `<basename>` = sanitised slug of the video title or video id.

```
docs/youtube-extraction/<basename>/
├── video.<ext>                # downloaded video (highest practical resolution)
├── metadata.json              # yt-dlp info-json
├── description.txt            # video description
├── transcript.md              # timestamped transcript
├── comments.json              # comments + threads
├── frames/                    # extracted frames (deleted after extraction unless retained)
├── files/                     # reconstructed source files (mirrors repo structure)
├── screenshots/               # full-frame or cropped images referenced from EXTRACTION.md
└── EXTRACTION.md              # final report
```

Only the temporary `frames/` directory is allowed to be deleted at the end.
Everything else is a persisted artifact and should remain on disk.

---

## Thin Commands and the Sub-Skills They Drive

Each thin command in `commands/` invokes this skill with a named operation. The
operation is implemented by chaining sub-skills.

| Command                  | Operation              | Sub-skills invoked, in order |
|-------------------------|----------------------|------------------------------|
| `/recreate-files`       | `recreate-files`      | video-acquisition → transcript-acquisition → comment-harvesting → frame-extraction → frame-content-recognition → file-reconstruction → extraction-reporting |
| `/extract-video-resources` | `extract-video-resources` | video-acquisition → transcript-acquisition → resource-identification → readme-fetching → divergence-detection → interest-assessment → resource-reporting |

When new thin commands are added, append them to this table and document the
operation below.

---

## Operation: recreate-files

**Goal.** Inspect every relevant signal in the video — frames, transcript, comments,
description — to identify files the creator discusses or shows. Recreate each one on
disk inside the current repo at a path inferred from the video context, deduplicating
lines that appear across multiple frames. End with a markdown report.

**Steps.**

1. **Validate parameters.** Apply the parameter contract above. Block on missing
   `url`; default `request` to "All files shown or discussed in the video" if the
   user gives no narrowing focus.

2. **Acquire the video.** Apply the `video-acquisition` sub-skill. Resolution
   matters here because OCR depth scales with pixel density — prefer 1080p or
   higher when the video offers it.

3. **Acquire the transcript.** Apply the `transcript-acquisition` sub-skill. If
   YouTube has auto-subs, use them; otherwise transcribe the local file.

4. **Harvest comments and metadata.** Apply the `comment-harvesting` sub-skill.
   Comments and the description often contain the canonical filenames or repo URLs
   that the speaker reads aloud — treat them as a primary source.

5. **Extract frames.** Apply the `frame-extraction` sub-skill in *file-reconstruction*
   mode (denser sampling, scene-aware) so consecutive frames overlap enough to
   stitch multi-page file content.

6. **Identify file content in frames.** Apply the `frame-content-recognition`
   sub-skill. For each frame, decide whether it shows file content (IDE, terminal
   `cat`, slide, README pane, etc.) and capture (path, language, visible lines).

7. **Reconstruct files on disk.** Apply the `file-reconstruction` sub-skill. For
   each unique file path detected:
   - Stitch its visible-line ranges across frames into a single canonical buffer
     without duplicating overlapping lines.
   - Cross-check the result against any verbatim quotes in the transcript or
     comments — these often supply lines that scrolled past too fast for OCR.
   - Place the file at a path appropriate to the calling repo's conventions
     (defer to existing folder structure if the repo already has one;
     otherwise honour the path shown in the video relative to the repo root).

8. **Generate the report.** Apply the `extraction-reporting` sub-skill to produce
   `docs/youtube-extraction/<basename>/EXTRACTION.md`.

9. **Clean up.** Delete the `frames/` working directory after successful
   reconstruction. Never delete `video.*`, transcripts, comments, screenshots, or
   the report.

---

## Operation: extract-video-resources

**Goal.** Analyze a video to identify and enrich external resources (GitHub repos, 
projects, tools, libraries) mentioned by the narrator. Extract narrator quotes with 
timestamps, fetch current project state, detect divergence from historical descriptions, 
and assess relevance based on local context. End with structured resource analysis and 
markdown report.

**Steps.**

1. **Validate parameters.** Apply the parameter contract. Block on missing `url`;
   default `request` to "All GitHub and open-source projects mentioned in the video"
   if the user gives no narrowing focus. Optionally accept `local_analysis_path` 
   parameter pointing to a directory for interest assessment.

2. **Acquire the video.** Apply the `video-acquisition` sub-skill. Standard resolution
   sufficient for transcript-based extraction (1080p preferred but not critical).

3. **Acquire the transcript.** Apply the `transcript-acquisition` sub-skill with full
   timestamp information. This is critical — must preserve timestamps for narrator quotes.

4. **Harvest comments and description.** Apply the `comment-harvesting` sub-skill.
   Extract all URLs and project mentions from video description and comments. These
   serve as primary resource list.

5. **Identify resources in transcript.** Parse transcript to locate narrator mentions
   of each resource:
   - Search for resource name/URL in transcript
   - Extract surrounding context (1-2 sentences) containing narrator's description
   - Record timestamp in `(~MM:SS)` format (tilde indicates approximation if needed)
   - Note if narrator description differs materially from current project state

6. **Fetch current project state.** For each identified resource:
   - If GitHub repo: fetch current README.md via GitHub API
   - If web resource: fetch current page title/description via HEAD request or web fetch
   - If package: fetch latest documentation from package registry
   - Extract official description/purpose (primary source of truth)

7. **Detect divergence.** Compare narrator's description against current state:
   - **Minor divergence (no flag):** feature renamed, docs updated, small API changes
   - **Significant divergence (flag in report):** major features added/removed, 
     use-case shifted, narrator praised now-deprecated feature, narrator missed 
     now-prominent features
   - Record as: `divergence_from_current: "Video emphasized X, current state focuses on Y"`

8. **Assess interest/relevance.** (Optional, requires `local_analysis_path`)
   - Scan provided directory for active projects (README, git log -20, file extensions)
   - Extract primary languages, recent focus areas, domain/problem-space
   - Score each resource 1-5 stars:
     - ⭐⭐⭐⭐⭐: Exact language + domain match to active projects
     - ⭐⭐⭐⭐: Strong match to major active project
     - ⭐⭐⭐: Relevant to general tech stack
     - ⭐⭐: Useful technique/complementary tool
     - ⭐: Technically interesting but orthogonal
   - Provide 1-2 sentence reasoning (language match, domain match, activity reference)

9. **Generate structured output.** Apply the `resource-reporting` sub-skill to produce:
   - `RESOURCES.md` — Markdown report with:
     - Summary (1-2 sentences about video focus)
     - Resources table: | Name | URL | Category | Description | Narrator Quote | Stars |
     - Transcript excerpts section with full quotes and divergence analysis
     - Key insights (patterns in narrator discussion, ecosystem trends)
     - Notes section (connections to other videos, follow-up questions)
   - `resources.json` — Structured data:
     ```json
     {
       "video": {
         "title": "...",
         "url": "...",
         "youtube_id": "...",
         "published_date": "YYYY-MM-DD",
         "duration_minutes": 28,
         "transcript_retrieved": true
       },
       "resources": [
         {
           "name": "project-name",
           "url": "https://github.com/user/repo",
           "category": "DevTools|AI/ML|Infrastructure|...",
           "readme_description": "Current official description",
           "narrator_quote": "Narrator's exact words about this resource",
           "timestamp": "~12:34",
           "interest_stars": 4,
           "interest_reasoning": "Matches your Python + ML focus",
           "divergence_from_current": null,
           "first_mentioned": "YYYY-MM-DD"
         }
       ],
       "metadata": {
         "total_resources": 42,
         "by_category": { "DevTools": 18, "AI/ML": 12, ... },
         "by_interest": { "5": 3, "4": 8, "3": 15, ... }
       }
     }
     ```

10. **Clean up.** Retain all transcript, metadata, and report artifacts. Delete
    temporary frames if any were extracted. All structured data is persisted.

---

## Resource Categories (Standard Taxonomy)

Use these categories for resource classification:

- **AI/ML** — Machine learning, LLMs, neural networks, NLP, computer vision
- **DevTools** — Developer utilities, CLI tools, build systems, linters, test frameworks
- **Infrastructure** — Kubernetes, orchestration, deployment, infrastructure-as-code, cloud services
- **Networking** — Protocols, proxies, load balancers, DNS, networking libraries
- **Security** — Authentication, encryption, vulnerability scanning, compliance
- **Databases** — SQL, NoSQL, vector stores, cache layers, data warehouses
- **Monitoring & Observability** — Logging, tracing, metrics, APM, dashboards
- **Web/HTTP** — Web frameworks, HTTP clients, servers, APIs, frontend libraries
- **Containers & Virtualization** — Docker, container runtimes, VMs, containerd
- **Streaming & Events** — Message queues, event streams, pub/sub, streaming processors
- **Storage** — File systems, object storage, distributed storage, backups
- **Performance** — Caching, optimization, profiling, benchmarking
- **Documentation & Learning** — Docs generators, tutorials, references, educational tools
- **Other** — Doesn't fit above categories

---

## Cross-Operation Principles

These apply to every operation, present or future:

- **Evidence first, inference second.** When the transcript and a frame disagree,
  prefer the transcript for words and the frame for code. Note the disagreement
  in reports. For resources, transcript narrator quotes are primary; current README
  is authoritative description.
- **Never duplicate content.** Avoid repeating the same resource/file across outputs.
  For resources: one entry per unique URL, even if mentioned multiple times.
  For files: stitch by longest common subsequence, not by concatenation.
- **Respect the target system.** If working in a project repo with existing structure,
  place outputs appropriately (docs/youtube-extraction/, README updates, etc.).
  Never overwrite existing analysis without user confirmation.
- **All user prompts go through `AskUserQuestion`.** Never write "type yes/no"
  or otherwise inline-print a question.
- **Idempotence.** Re-running a command on the same URL must not corrupt
  prior artifacts. If a target file already exists with content from a prior
  extraction, diff before overwriting and surface the conflict via
  `AskUserQuestion`.
- **Transcript is truth.** Narrator quotes from transcript are more reliable than
  visual content. If transcript unavailable, note in `transcript_retrieved: false`
  and proceed with description-based analysis.
- **Current state matters.** For resources, always fetch current README/docs as
  description source, not narrator paraphrase. Flag divergence when narrator
  emphasis differs from current state.
- **Interest scoring is contextual.** Interest assessments only work with local
  project analysis. Without `local_analysis_path`, default all scores to 3 stars
  with reasoning "Relevance depends on your active projects".

---

## Tooling Prerequisites

The sub-skills assume these tools are available on PATH. If any is missing, fall
back to the documented alternatives in the relevant sub-skill.

- `yt-dlp` — video, metadata, comments, subtitles
- `ffmpeg` / `ffprobe` — frame extraction, scene detection
- `whisper` or `whisper.cpp` — transcript fallback when YouTube auto-subs are
  absent
- A multimodal vision model (this assistant's own image-reading capability via
  the `Read` tool on PNG frames) — frame content recognition

---

## Diagram

[View diagram](diagram.html)
