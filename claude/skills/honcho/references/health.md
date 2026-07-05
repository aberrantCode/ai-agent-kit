# Honcho health & inspection

Diagnose whether a **self-hosted Honcho** deployment is actually working, and
inspect any layer (messages, conclusions, context, peers, sessions, workspaces)
on request. This is the deep end-to-end verdict — the only way to catch a
silently-stalled deriver.

> This reference is deployment-agnostic. Replace the placeholders — `<api-url>`,
> `<host>`, `<workspace>`, `<db>` — with your own values, or keep a short
> deployment-specific note in your repo that maps them.

## The one insight that governs everything

Honcho's health is **split across two surfaces that cannot see each other**:

| Surface | What it tells you | Reaches it how | Blind to |
|---|---|---|---|
| **Client reads** (SDK / MCP tools / `honcho` CLI) | THROUGHPUT — what an agent can read back *right now*: context, conclusions, search hits, config | over the API, from anywhere | the deriver. Returns happily even while derivation has failed for days |
| **Server side** (Postgres + containers on the host) | DEPTH — queue backlog, errored items, embedding progress, container liveness | DB/`docker` access on the host | whether clients are actually getting *useful* context back |

A real verdict needs **both**. Checking only the client side is exactly how a
`Missing API key for <llm> model config` failure can hide for days: the API
serves, `get_context` returns stale-but-plausible data, and nothing surfaces
that every new memory is being silently error-marked. **Never declare "healthy"
from the client side alone.**

## Data model (the vocabulary)

```
workspace
  └── peer            a human user  +  the AI assistant
        └── session   e.g. one per conversation thread / directory / worktree
              └── message   user/assistant turns ingested by your app
                    └── queue item   the deriver's work unit (processed bool, error text)
                          └── document   a derived fact, embedded as a vector
        └── conclusion   a saved insight ABOUT a peer (attaches to the peer, not a session)
        └── representation   the rolled-up "what we know about this peer" string
```

- **Conclusions** attach to the **peer**, not the session — they persist across
  sessions. Listing conclusions is peer-scoped.
- **`is_active`** is set true at session creation and, in many deployments,
  **never cleared** — hundreds of "active" sessions is expected, not a bug.
- The **deriver** is the async worker that turns messages → documents +
  representations. It is the part most likely to be quietly broken.

## Default workflow — the health verdict

When asked "is Honcho working?" (or anything implying it), do all three, then
render the verdict card.

### 1. Client side — what can the agent see? (fast)

- **Config** — endpoint `baseUrl` points at your deployment; `saveMessages`
  true; note any warnings (env-var shadowing, legacy config).
- **`get_context` / `session context`** — does it return a representation +
  recent conclusions? Empty/error = nothing to read back.
- **List conclusions** — count + recency. Are they coherent and about the
  *user* (not the AI narrating itself — see failure signatures)?
- **Dialectic `chat`** with a known fact ("what does the user work on?") — does
  it return something true? This exercises the full representation path.

Healthy looks like: config points at the right endpoint, `get_context` returns
a populated representation, conclusions are recent and about the user.

### 2. Server side — is the deriver actually keeping up?

Run a **read-only** probe against the host (see `failure-signatures.md` §2 for
the exact SQL and §3 for container/log inspection). At minimum check:

- `/health` responds on the API,
- all core containers are `Up` and which deriver mode is live,
- queue total / pending / errored + oldest-pending age,
- the **distinct error strings** on errored items (the smoking gun),
- embedding progress + vector dimension,
- the deriver log tail.

Interpret with the failure-signature catalog in `failure-signatures.md`.

### 3. Render the verdict

Give a tight card, not a wall of probe output:

```
Honcho health — <date>
  API            up (<api-url> {"status":"ok"})
  Containers     N/N up; deriver = <mode>
  Queue          pending 0 · errored 0 · oldest-pending 0s     [DRAINED]
  Embeddings     <n> docs @ dim <d>                            [OK]
  Memory I/O     get_context populated; <n> conclusions, recent [OK]
  GUI            <explore-ui> reachable   (if deployed)
  VERDICT        WORKING — deriver current, memory readable.
```

If something is wrong, lead with the **one** failing line + the specific fix,
then the card. Don't bury the lede in prose.

## Inspecting a specific layer (on request)

The operator may just want to look, not health-check:

- **"what does Honcho remember about me?"** → list conclusions (paginate) +
  get representation (lighter than full context).
- **"what did we discuss about X?"** → search with **workspace** scope to span
  all sessions (session scope is one thread only).
- **"how many sessions/peers/workspaces?"** → the census SQL in
  `failure-signatures.md` §2, or browse visually if you run an explore GUI
  (e.g. OpenConcho).
- **"is my memory being saved?"** → config (`saveMessages`) + is the `messages`
  count rising run-over-run?

## Hard rules

- **Read-only by default.** Inspection and health-checks never mutate. Only
  `create_conclusion` / `delete_conclusion` / `set_config` write — never call
  those during a health check, and confirm with the operator before any
  `set_config` (workspace/endpoint changes typically wipe cached context).
- **Credentials come from your secret manager**, never hard-code or print them.
  The deriver needs a valid LLM API key; a missing/expired one is the #1 cause
  of a silently-failing deriver.
- **Don't reset the queue blindly.** The retry reset must exclude
  `reconciler` / `dream` task types — they carry partial unique indexes and a
  blanket reset raises a duplicate-key violation. Use the exact SQL in
  `failure-signatures.md` §4.
