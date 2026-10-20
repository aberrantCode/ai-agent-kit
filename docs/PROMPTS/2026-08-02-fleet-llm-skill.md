# Session handoff — build a global `fleet-llm` skill + thin command (Open WebUI / ollama fleet)

Fresh session, **no memory** of the work that produced this. Everything needed is below — including the
exact fleet API shapes, already verified live this session. Do not re-derive them.

> **Note the repo:** you are in the **`ai-agent-kit` archive** (`C:\development\ai-agent-kit`), the
> source-of-truth for global Claude/Codex/Gemini skills — NOT a normal app repo.

---

## Orientation

- **Read `ai-agent-kit`'s own `CLAUDE.md`, `README.md`, and `docs/requirements/canonical-repo.md`
  first** and follow them exactly — they define the G-rules, the `manifest.json` → generated
  `CATALOG.md` flow, the per-vendor layout, and the skill-authoring conventions. Do NOT restate or
  guess those; obey the archive's docs.
- Global skills live at **`claude/skills/<name>/`**; global commands at **`claude/commands/<name>.md`**.
  Read one existing skill (e.g. `claude/skills/llm-patterns/SKILL.md`) to match SKILL.md frontmatter +
  structure. The global `skill-creator` skill is available if you want its scaffolding.
- **Your worktree + branch already exist — work there, do not create another:**
  - Worktree `C:\development\ai-agent-kit\.worktrees\fleet-llm-skill`
  - Branch `feat/fleet-llm-skill` (from `origin/dev` @ `064a20f`).
- **Goal:** a global skill + one thin command that let any agent talk to the operator's self-hosted
  **Open WebUI / ollama fleet** — list models, chat (prompt→response), pull/remove models, embeddings,
  and a raw passthrough for arbitrary endpoints/params. Package what a prior session did ad-hoc into a
  clean, reusable CLI.

---

## HARD CONSTRAINTS (you run with `--dangerously-skip-permissions`; this text is the only guardrail)

1. **Never commit a real token or the config file into the archive.** The token lives ONLY in
   `~/.claude/fleet-llm.env` (outside any repo). The repo gets code + docs + an `.example` template.
   If you ever see a token in a staged diff, stop.
2. **Never push to `dev`/`main` directly.** Open a PR to `dev`. **Do NOT self-merge** — leave it for
   operator review.
3. The fleet host is **internal-only (VLAN30, `192.168.30.53`)** — the skill talks to it over the LAN;
   it is not a public service. Don't add public exposure.
4. **Testing etiquette:** `models`, `chat`, `embed`, `raw`, and error paths are cheap — test freely.
   **Do NOT `pull` a large model as a test** (multi-GB download on the operator's GPU box); test the
   pull path against an already-present tiny tag or just dry-run/validate the request. Never `rm` a
   model that was already on the host — only remove one you pulled.
5. If a task needs an action you can't take unattended, STOP and report — don't improvise around auth.

---

## State already established (VERIFIED LIVE this session — do NOT re-derive)

**The fleet API (Open WebUI in front of ollama):**
- Base URL: **`http://192.168.30.53:3000`**. Auth header on every call:
  **`Authorization: Bearer <service-account token>`**.
- **OpenAI-compatible surface** under `/openai/v1`:
  - List models: `GET /openai/v1/models` → `{"data":[{"id":"..."}...]}`.
  - Chat: `POST /openai/v1/chat/completions` body
    `{"model":M,"messages":[{"role":"system|user","content":...}],"temperature":T,"max_tokens":N,"stream":false}`
    → `choices[0].message.content`.
  - Embeddings: `POST /openai/v1/embeddings` `{"model":"nomic-embed-text","input":"..."}`.
- **ollama proxy** under `/ollama` (Open WebUI proxies the native ollama API):
  - Pull: `POST /ollama/api/pull` `{"name":"<model>"}` → streams NDJSON; ends `{"status":"success"}`.
  - Delete: `DELETE /ollama/api/delete` `{"name":"<model>"}`.
  - On-disk tags (size/date): `GET /ollama/api/tags` → `{"models":[{"name","size","modified_at"}]}`.
- **ollama's native `:11434` is compose-net-only — unreachable from the LAN. Always go through Open
  WebUI on `:3000`.** (Verified: direct `:11434` from off-host fails.)
- Models currently on the fleet (for test/default picking): `gemma4:e4b` (+ `-test`/`-qat` variants),
  `llama3.1:8b`, `nomic-embed-text:latest`, `qwen3.5:9b`, `qwen3.5:latest`. **Good default chat model:
  `qwen3.5:9b`.** Caveat verified this session: **`qwen3.5:latest` returns EMPTY content** (a "thinking"
  variant) — do not use `:latest`; the skill's default should be an explicit tag like `qwen3.5:9b`.

**Auth design (operator decision — local config file, chosen this session):**
- The skill reads config from **`~/.claude/fleet-llm.env`** (KEY=VALUE), with **environment-variable
  fallback**. Keys: `FLEET_LLM_BASE_URL`, `FLEET_LLM_API_KEY`, `FLEET_LLM_DEFAULT_MODEL` (default
  `qwen3.5:9b`). The file is single-user, gitignored-by-location (it's under `~/.claude/`, not a repo).
- A `setup` subcommand writes that file (from flags or interactively). **Optional convenience seed**
  (this operator only): the token already exists in AC_OPBTA SOPS — on ac-devops,
  `sops -d ~/repos/AC_OPBTA/secrets/repo-radar.enc.yml | python3 -c 'import sys,yaml;print(yaml.safe_load(sys.stdin)["openai_api_key"])'`
  yields a valid fleet token (via `ssh ubuntu@192.168.30.15`). Offer a `setup --from-ac-devops-sops`
  flag that does this, but it must be OPTIONAL — the skill is global and must work with a plain
  base-url/api-key too.

---

## Tasks — in order

### Task 1 — The CLI (`claude/skills/fleet-llm/scripts/fleet_llm.py`)
Python 3 (cross-platform: Windows/git-bash/Linux; stdlib only — `urllib`/`json`, no `requests` dep).
Config resolution: `~/.claude/fleet-llm.env` → env vars → error with a pointer to `setup`. Subcommands:
- `setup [--base-url U] [--api-key K] [--default-model M] [--from-ac-devops-sops]` — write the config
  file (0600); print where it landed; never echo the token.
- `models` — list model ids (`GET /openai/v1/models`); `--json` for raw.
- `chat "<prompt>" [--model M] [--system S] [--temperature T] [--max-tokens N] [--json]` — print the
  assistant text (or full JSON with `--json`). Reads prompt from `-` / stdin too.
- `pull <model>` — stream progress, report success/failure.
- `rm <model>` — delete (guard/confirm semantics per Hard Constraint 4).
- `embed "<text>" [--model nomic-embed-text] [--json]` — return the vector (or its length + head).
- `raw <METHOD> <path> [--data JSON]` — **the passthrough**: arbitrary request against the host with
  extra params, e.g. `raw POST /openai/v1/chat/completions --data '{...}'` or a native ollama endpoint.
  This satisfies "run the request if needed (extra parameters passed into the host)".
- Sensible errors (non-200 → show status + body head; empty content → warn, as with `qwen3.5:latest`).
- Done = each subcommand works against the live fleet (see Task 4).

### Task 2 — `SKILL.md` (`claude/skills/fleet-llm/SKILL.md`)
Frontmatter `name` + a trigger-rich `description` (so it fires on "ask the fleet / local LLM / ollama /
open webui / run a prompt on my GPU box / list local models / pull a model", etc.). Body: one-time
`setup`, then a short usage block per subcommand with real examples, the config/env contract, the
`:11434`-is-compose-net-only gotcha, and the `qwen3.5:latest`-returns-empty caveat. Match the
archive's existing SKILL.md shape. Add an `.example` config template
(`claude/skills/fleet-llm/fleet-llm.env.example`).

### Task 3 — Thin command (`claude/commands/fleet-llm.md`)
A thin `/fleet-llm` command that invokes the skill (mirror an existing thin command's shape). Keep it a
one-op wrapper that passes args through to the CLI.

### Task 4 — Test live + register + push global
- Run `setup` (seed from SOPS via the optional flag is fine here), then exercise `models`, `chat`
  (`qwen3.5:9b`), `embed`, `raw`, and an error path. Paste the real outputs into your report.
- Register the skill + command in `manifest.json` and regenerate `CATALOG.md`
  (`pwsh ./scripts/generate-catalog.ps1 -Force`) — per the archive's canonical-repo rules; CI/G-rules
  expect the catalog in sync.
- **Deploy to the global profile so it's usable now:** use the archive's `push-skill` (or
  `install-skill`) flow to copy the bundle to `~/.claude/skills/fleet-llm/` + the command to
  `~/.claude/commands/fleet-llm.md`. Confirm the command resolves.
- Done = live tests pass, catalog regenerated + in sync, skill live in `~/.claude/`.

### Task 5 — PR (do NOT merge)
`gh pr create --base dev` with a Summary (what the skill does, the auth model, the endpoints wrapped),
the live-test evidence, and a Test Plan. Update `docs/progress.md`-equivalent if the archive keeps one.
Leave the PR open for operator review.

---

## Delegation
Main loop pinned to **Opus** (`ANTHROPIC_MODEL=claude-opus-4-8`), though much of this is mechanical —
`/model` down to Sonnet is reasonable once the CLI/SKILL design is set. Delegate to `model:"haiku"`
(state it explicitly), parallel where independent: reading an existing SKILL.md + thin-command for
shape, reading `docs/requirements/canonical-repo.md` for the manifest/catalog rules, extracting the
`generate-catalog.ps1` invocation. Keep in the main loop: the CLI subcommand design, the auth/config
contract, and the live-test verdicts.

**Delegation logging (required).** Log escalations/redos/drops with
`C:\Users\erik.OPBTA\.claude\skills\continue-new-session-prompt\scripts\log-delegation-outcome.ps1`
(`-Category`, `-FailureMode`, one-line `-Evidence`). **Final step:** log totals
`-Outcome ok -Dispatches N` per category, each **`-PromptPath 'C:\development\ai-agent-kit\docs\PROMPTS\2026-08-02-fleet-llm-skill.md'`**
— the retirement gate needs this tally.

## Finishing
Live tests pass; catalog regenerated + in sync; skill+command deployed to `~/.claude/`; PR opened to
`dev` and **left unmerged**; delegation tally logged; **do not delete this prompt file.** Report terse,
ending in one numbered decision list; verify counts before stating them; correct your own earlier
claims in one line. Then stop.
