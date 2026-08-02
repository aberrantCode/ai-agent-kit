---
description: Talk to the self-hosted Open WebUI / ollama fleet — list local models, run a prompt on the GPU box, chat with a local LLM, get embeddings, pull/remove models, or hit any fleet endpoint raw. Thin wrapper over the fleet-llm skill.
---

Apply the `fleet-llm` skill and run its CLI (`scripts/fleet_llm.py`) with the
trailing arguments passed straight through.

Map the request to a subcommand:

- **list models / what's on the fleet** → `models`
- **ask the fleet / run a prompt / chat with the local LLM** → `chat "<prompt>"`
  (default model `qwen3.5:9b`; never `qwen3.5:latest` — it returns empty)
- **embed** → `embed "<text>"` (default `nomic-embed-text`)
- **pull a model** → `pull <tag>` (multi-GB download — confirm intent first)
- **remove a model** → `rm <tag>` (only remove one that was pulled deliberately)
- **anything else / extra params** → `raw <METHOD> <path> [--data JSON]`

If config is missing, run `setup` first (see the skill for the base-url/api-key
contract and the optional `--from-ac-devops-sops` seed). The host is LAN-only
(VLAN30) — off-network, calls fail with a clear "Cannot reach fleet" message.
