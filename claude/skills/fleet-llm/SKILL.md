---
name: fleet-llm
category: AI & LLM
description: Talk to the operator's self-hosted Open WebUI / ollama fleet from the terminal — list local models, run a prompt on the GPU box, chat with a local LLM, get embeddings, pull or remove models, or hit any fleet endpoint raw. Triggers on "ask the fleet", "ask my local LLM", "run this on ollama / open webui", "run a prompt on my GPU box", "list local models", "pull a model", "embed with nomic", "which models are on the fleet", and similar.
version: 2026-08-02
---

# fleet-llm

A stdlib-only Python CLI that talks to the operator's self-hosted **Open WebUI**
instance (which fronts **ollama**) over the LAN. Use it to list models, chat,
embed, pull/remove models, or hit any endpoint raw.

**Script:** `scripts/fleet_llm.py` (Python 3, stdlib only — no `pip install`).
Invoke with `python scripts/fleet_llm.py <subcommand>` from the skill directory,
or with the full path to the script.

---

## One-time setup

The CLI reads config from `~/.claude/fleet-llm.env` (a `KEY=VALUE` file), falling
back to environment variables. Write the file once:

```bash
python scripts/fleet_llm.py setup \
  --base-url http://192.168.30.53:3000 \
  --api-key <service-account-bearer-token> \
  --default-model qwen3.5:9b
```

Run with no flags for an interactive prompt. The token is **never echoed** (setup
prints a redacted fingerprint) and the file is written `0600` where the OS allows.

**Operator convenience (this workstation only):** `setup --from-ac-devops-sops`
fetches the token from AC_OPBTA SOPS over ssh (`ubuntu@192.168.30.15`) instead of
passing `--api-key`. This is optional — the skill works with a plain base-url +
api-key anywhere.

### Config contract

| Key | Purpose | Default |
|---|---|---|
| `FLEET_LLM_BASE_URL` | Open WebUI base URL | — (required) |
| `FLEET_LLM_API_KEY` | Service-account bearer token | — (required) |
| `FLEET_LLM_DEFAULT_MODEL` | Default chat model | `qwen3.5:9b` |

Resolution order per key: `~/.claude/fleet-llm.env` → environment variable →
error pointing at `setup`. A template lives at `fleet-llm.env.example`.

---

## Usage

### List models
```bash
python scripts/fleet_llm.py models            # one model id per line
python scripts/fleet_llm.py models --json      # raw /openai/v1/models payload
```

### Chat
```bash
python scripts/fleet_llm.py chat "Summarize the CAP theorem in two sentences."
python scripts/fleet_llm.py chat "Explain X" --model llama3.1:8b --system "Be terse." --temperature 0.2 --max-tokens 300
echo "long prompt from a file" | python scripts/fleet_llm.py chat -   # read stdin
python scripts/fleet_llm.py chat "..." --json    # full JSON (usage, finish_reason, ...)
```
Prints the assistant text. If the model returns **empty** content it warns and
exits non-zero (see the thinking-model caveat below).

> **Raw passthrough note for git-bash:** only the `raw` subcommand takes a path
> argument, and git-bash (MSYS) rewrites a leading-slash arg like `/ollama/api/tags`
> into a Windows path. The CLI auto-recovers paths under `/openai`, `/ollama`, and
> `/api`; for any other endpoint prefix with `MSYS_NO_PATHCONV=1`. `models`, `chat`,
> and `embed` are unaffected (their paths are internal).

### Embeddings
```bash
python scripts/fleet_llm.py embed "text to embed"                 # dim=768 head=[...]
python scripts/fleet_llm.py embed "text" --model nomic-embed-text --json
```

### Pull / remove models
```bash
python scripts/fleet_llm.py pull llama3.1:8b     # streams progress; reports success
python scripts/fleet_llm.py rm my-scratch-model  # confirms first; -y to skip
```
**Do not `pull` a large model casually** — it is a multi-GB download onto the
operator's GPU box. Only `rm` a model you pulled yourself.

### Raw passthrough
The escape hatch: issue any request against the host with arbitrary params.
```bash
python scripts/fleet_llm.py raw GET /ollama/api/tags
python scripts/fleet_llm.py raw POST /openai/v1/chat/completions \
  --data '{"model":"qwen3.5:9b","messages":[{"role":"user","content":"hi"}],"stream":false}'
python scripts/fleet_llm.py raw POST /openai/v1/embeddings --data '{"model":"nomic-embed-text","input":"hi"}'
```
`--data -` reads the JSON body from stdin. Response is printed as pretty JSON.

---

## Endpoints wrapped

- **OpenAI-compatible** (`/openai/v1`): `models`, `chat/completions`, `embeddings`.
- **ollama proxy** (`/ollama/api`): `pull`, `delete`, `tags` — Open WebUI proxies
  the native ollama API.

## Gotchas (verified live)

- **Always go through Open WebUI on `:3000`.** ollama's native `:11434` is
  compose-net-only and unreachable from the LAN.
- **`qwen3.5` tags are "thinking" models** — they emit a hidden `reasoning` pass
  before the answer (the response carries both a `reasoning` and a `content` field;
  the CLI prints only `content`). A **low `--max-tokens` can be fully consumed by the
  reasoning pass, leaving `content` empty** — `chat` then warns and exits non-zero.
  Fix: drop `--max-tokens` or raise it. (Verified 2026-08-02: both `qwen3.5:9b` and
  `qwen3.5:latest` return proper content uncapped; `qwen3.5:9b` needed ~1900 tokens
  for a one-sentence answer because of the reasoning pass. The default stays the
  explicit tag `qwen3.5:9b`.)
- The host is **LAN-only (VLAN30, `192.168.30.53`)**. Off-network, every call
  fails with a clear "Cannot reach fleet" message — get on the LAN.

## Errors

Non-2xx responses print `HTTP <status> <reason>` plus the body head. Network
failures print a "Cannot reach fleet" hint. Empty prompts, invalid `--data` JSON,
and missing config all fail fast with a one-line reason and exit 1.
