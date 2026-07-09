---
name: honcho
description: Work with Honcho — the open-source, AI-native memory backend for stateful agents. Use when integrating Honcho memory/social-cognition into a Python or TypeScript codebase, migrating the Honcho SDK between versions, inspecting or debugging a Honcho deployment via the `honcho` CLI, or health-checking a self-hosted Honcho instance (peers, sessions, conclusions, representations, the deriver queue). Triggers on: "add Honcho", "Honcho SDK", "peer.chat", "dialectic", "observe_me", "conclusions/representations", "is Honcho working", "deriver stalled", "migrate honcho".
allowed-tools: Read, Glob, Grep, Edit, Write, WebFetch, AskUserQuestion, Bash(uv:*), Bash(bun:*), Bash(npm:*), Bash(honcho:*), Bash(jq:*), Bash(docker:*), Bash(psql:*)
version: '1.0.0'
---

# Honcho

Honcho is an open-source memory library for building **stateful agents**. You
feed it the messages from your conversations; background reasoning models extract
premises, draw conclusions, and build a rich **representation** of each
participant over time. Your agent then queries those representations on demand
(`peer.chat("What does this user care about?")`) and gets grounded answers.

**The mental model:**

- **Peers** are any participant — human or AI. Both are modeled the same way.
  `observe_me` / `observe_others` control which peers Honcho reasons about.
  Typically observe your users (`observe_me=True`) but not your AI
  (`observe_me=False`).
- **Sessions** scope conversations between peers.
- **Messages** are the raw data you feed in. Honcho reasons about them
  asynchronously (via the **deriver**) and stores the result as each peer's
  **representation**. No messages → no reasoning → no memory.
- Access memory through `peer.chat(query)` (ask a question, get a reasoned
  answer) and/or `session.context()` (formatted history + representations).

## Router — pick the task

| You want to… | Read |
|---|---|
| **Integrate** Honcho into a Python/TS codebase (SDK setup, peers, sessions, dialectic tool-call, context patterns) | [`references/integration.md`](references/integration.md) |
| **Inspect / debug** a deployment via the `honcho` CLI (peer memory, session context, queue status, dialectic quality) | [`references/cli.md`](references/cli.md) |
| **Health-check** a self-hosted instance — "is Honcho actually working?" | [`references/health.md`](references/health.md) + [`references/failure-signatures.md`](references/failure-signatures.md) |
| **Migrate** the Python SDK (v1.6.0 → v2.1.1) | [`references/migrate-python/guide.md`](references/migrate-python/guide.md) |
| **Migrate** the TypeScript SDK (v1.6.0 → v2.1.1) | [`references/migrate-typescript/guide.md`](references/migrate-typescript/guide.md) |

> Always check the latest SDK versions before integrating or migrating:
> <https://honcho.dev/docs/changelog/introduction>

## Quickstart

**Install** — Python: `uv add honcho-ai` · TypeScript: `bun add @honcho-ai/sdk`

**Python (sync):**

```python
from honcho import Honcho
from honcho.api_types import PeerConfig
import os

honcho = Honcho(workspace_id="your-app", api_key=os.environ["HONCHO_API_KEY"])

user = honcho.peer("user-123")
assistant = honcho.peer("assistant", configuration=PeerConfig(observe_me=False))
session = honcho.session("conversation-1")

session.add_messages([
    user.message("I keep my configs in TOML, not JSON"),
    assistant.message("Got it — I'll use TOML."),
])

print(user.chat("What config format does this user prefer?"))
```

**TypeScript (async by default):**

```typescript
import { Honcho } from '@honcho-ai/sdk';

const honcho = new Honcho({ workspaceId: "your-app", apiKey: process.env.HONCHO_API_KEY });
const user = await honcho.peer("user-123");
const assistant = await honcho.peer("assistant", { configuration: { observeMe: false } });
const session = await honcho.session("conversation-1");

await session.addMessages([
  user.message("I keep my configs in TOML, not JSON"),
  assistant.message("Got it — I'll use TOML."),
]);

console.log(await user.chat("What config format does this user prefer?"));
```

## Rules of thumb

- **One workspace per application.** Don't spread data across workspaces.
- **Create peers for AI assistants too**, with `observe_me=False` — otherwise the
  AI's own narration pollutes the user's representation.
- **Always store messages** after each exchange — that's what feeds the deriver.
- **Never block on the deriver.** Derivation is asynchronous; don't poll for the
  queue to be "empty" — new messages arrive continuously.
- When debugging memory, verify **both** surfaces: what clients can read back
  *and* the server-side deriver queue. A healthy-looking API can sit on top of a
  deriver that has failed for days (see `references/health.md`).

## Resources

- Docs: <https://honcho.dev/docs>
- API reference: <https://honcho.dev/docs/v3/api-reference/introduction>
- Changelog / SDK versions: <https://honcho.dev/docs/changelog/introduction>

## Diagram

[View diagram](diagram.html)
