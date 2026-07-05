# Honcho failure-signature catalog + raw inspection SQL

Deep reference for Honcho health-checks. Read this when a probe surfaces a
non-obvious state or the operator wants to inspect a layer directly. Every SQL
block is read-only.

> Deployment-agnostic. Substitute your own host, container names, endpoint, and
> secret-manager commands where placeholders appear.

## Table of contents

1. Failure signatures (symptom → cause → fix)
2. Raw inspection SQL (queue, messages, sessions, conclusions, documents)
3. Container & log inspection
4. The queue-retry reset (the one mutation, and its footgun)

---

## 1. Failure signatures

### `Missing API key for <llm> model config` (the silent-outage signature)
- **Where**: every errored queue item carries this string.
- **Cause**: the deriver's LLM API key is empty/unset. The deriver makes LLM
  calls to derive facts; with no key it error-marks every item. Errored items
  are retained-but-processed and **never auto-retry**.
- **Fix**: seed the key in your secret manager / deriver env, redeploy the
  deriver, then reset the errored rows (§4).

### `RetryError` / `APIConnectionError` on errored items (deriver couldn't reach the LLM)
- **Cause**: the deriver had a *configured* endpoint but could not **connect**
  to it at derive time — the LLM host was down/rebooting, a network partition,
  or the inference server not answering. Distinct from `Missing API key` (no key
  at all) and `401`/`404` (reached it, rejected).
- **Crucial nuance**: errored items are **retained-but-processed and never
  auto-retry**. So a pile of `APIConnectionError` rows with **`pending=0` and a
  log tail showing recent successful derivations** is **historical** — the
  deriver is working *now*; those are observations lost during a past
  connectivity blip. Report it as "working, with N historical errored items
  (optional cleanup)", NOT as broken.
- **Fix (optional, to reclaim lost observations)**: confirm the LLM host is
  reachable, then reset+retry the errored rows (§4). If they re-error,
  connectivity is still down — fix that first.

### Deriver stalled — pending high, oldest-age hours/days, errored ~0
- **Cause A**: the expected drainer isn't running. Confirm the deriver
  container/process is actually up and in the intended mode (always-on worker vs
  on-demand fallback).
- **Cause B**: batch-flush disabled. Without a flush flag, the deriver only
  claims a `representation` work unit once pending tokens cross the batch
  threshold. A backlog spread thinly across many sessions (sparse n=1 use) never
  reaches the threshold, so the deriver idles. Ensure the flush flag
  (`DERIVER_FLUSH_ENABLED=true` or equivalent) is set.
- **Fix**: confirm which mode is intended; ensure the flush flag is on.

### Embedding-dimension mismatch — `vector_dim` wrong, or deriver exits citing dims
- **Cause**: the pgvector column dimension doesn't match the embedding model's
  output (classic case: column is the OpenAI default `vector(1536)` but the
  configured embed model emits 768). Deriver startup gates on the column
  matching the configured dimension.
- **Fix**: run your embedding-migration step to rewrite the column to the
  correct dimension (cheap when the embedding tables are empty).

### 401 / unauthorized in deriver log
- **Cause**: the LLM bearer token is revoked/invalid.
- **Fix**: rotate the key in your provider, update the deriver's secret, redeploy.

### 404 model not found
- **Cause**: the chat or embed model isn't pulled/available on the inference
  host, or is missing a tag.
- **Fix**: confirm the model is installed on the inference host; pull it if not.
  You need both a chat model and an embedding model.

### Conclusions are garbled / about the wrong actor
- **Symptom**: conclusions like *"<user> acknowledged a merge pull request"* or
  AI-about-AI self-observations; conclusion count balloons.
- **Cause**: full assistant turns (tool narration, PR bodies) were fed to the
  deriver, and both peers had `observe_me=true`, so the AI's own narration
  became "facts about the user."
- **Fix**: set `observe_me=False` on AI peers; tune assistant-message
  summarization / max-assistant-tokens via `set_config`; purge polluted
  conclusions. Confirm with the operator first — these are mutations.

### `{"detail":"Not Found"}` at `/`, or 401/405 on the API
- **`/` 404**: the root redirect (e.g. `/` → `/docs`) isn't configured — not a
  Honcho fault.
- **`401 No access token`**: hitting `/v3/*` without the Bearer. `/health` is
  public; `/v3/*` + `/mcp` need auth.
- **`405` on `GET /v3/workspaces`**: that path is POST-only; the SDK lists via a
  different route. Not a fault.

---

## 2. Raw inspection SQL

Run against the Honcho Postgres database (read-only). Adapt the connection to
your host — e.g. `docker exec <postgres-container> psql -U <user> -d <db> -tAc "<SQL>"`.

Typical schema: `sessions(is_active, workspace_name)`, `messages(token_count,
session_name, workspace_name)`, `queue(processed bool, error text, created_at,
task_type, workspace_name)`, `peers`, `workspaces`, `documents(embedding vector)`.

```sql
-- Queue health, per workspace
SELECT workspace_name, count(*) total,
       count(*) FILTER (WHERE NOT processed) pending,
       count(*) FILTER (WHERE processed AND error IS NULL) ok,
       count(*) FILTER (WHERE error IS NOT NULL) errored
FROM queue GROUP BY workspace_name ORDER BY 1;

-- Oldest pending item age (seconds)
SELECT EXTRACT(EPOCH FROM (now()-min(created_at))) FROM queue WHERE NOT processed;

-- Distinct error strings (the smoking gun)
SELECT count(*), left(error,120) FROM queue
WHERE error IS NOT NULL GROUP BY 2 ORDER BY 1 DESC;

-- Pending by task_type (representation vs reconciler/dream)
SELECT task_type, count(*) FROM queue WHERE NOT processed GROUP BY 1;

-- Embedding progress + live dim
SELECT count(embedding), max(vector_dims(embedding)) FROM documents;

-- Message ingest by workspace (is anything being saved?)
SELECT workspace_name, count(*), COALESCE(sum(token_count),0)
FROM messages GROUP BY 1 ORDER BY 2 DESC;

-- Sessions: total vs active (active is often never cleared — expect many)
SELECT workspace_name, count(*), count(*) FILTER (WHERE is_active)
FROM sessions GROUP BY 1 ORDER BY 2 DESC;

-- Per-table row census
SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY relname;
```

> Conclusions are NOT a top-level Postgres count you should eyeball for content
> — read them through the SDK/MCP `list_conclusions` (peer-scoped, returns
> id + content + createdAt), which respects observation mode.

---

## 3. Container & log inspection

```bash
docker ps -a --filter name=honcho --format "{{.Names}}\t{{.Status}}"
docker logs <deriver-container> --tail 50   # derivation errors, 401/404/OOM
docker logs <api-container> --tail 50        # request errors, auth
docker inspect <deriver-container> --format "{{.State.Status}}"
```

A typical stack: `honcho-api`, `honcho-deriver`, `honcho-postgres`,
`honcho-redis`, plus an optional metrics exporter. Native API metrics usually
need `METRICS_ENABLED=true` (else `/metrics` returns `Metrics are disabled`).

---

## 4. The queue-retry reset (the one mutation, and its footgun)

After fixing an errored-deriver cause, re-enqueue the errored rows:

```sql
UPDATE queue SET processed=false, error=NULL
WHERE processed AND error IS NOT NULL
  AND task_type NOT IN ('reconciler','dream');
```

**The `reconciler`/`dream` exclusion is required.** Those task types carry
partial unique indexes (`uq_queue_{reconciler,dream}_pending_work_unit_key`)
forbidding more than one *pending* row per `work_unit_key`. A blanket
`WHERE processed=true` reset raises `duplicate key value violates unique
constraint`. The derivation backlog is `task_type='representation'`, which has
no such constraint. This is a **mutation** — confirm with the operator.
