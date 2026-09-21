---
description: Start the application — probes whether it is already running first (near-instant no-op if so), then uses the cached start intelligence at docs/framework/start-app.md when fresh, otherwise discovers startup scripts, selects the right one, executes it, and handles failures. Pass an optional prompt to target a specific stack or component (e.g. /start-app run the backend in prod mode), --restart to force a fresh boot even if already running, --refresh to force a full re-investigation, or --update to rewrite the cache after solution changes.
---

Use the `start-app` skill to start the application.

The skill persists two layers of state: a committed **discovery cache** (`docs/framework/start-app.md`, "what command do I run?") and a gitignored **runtime sidecar** (`docs/framework/.start-app-runtime.json`, "is it already up?"). Every run first probes the sidecar's health URLs — if the app is already running for the requested variant, it short-circuits and starts nothing. Pass `$ARGUMENTS` straight through so the skill can route to the right mode:

- **(no args)** — pre-flight probe; if already running, report and stop. Otherwise use the cache if fresh, else generate it after a successful run
- **`--restart`** / "restart" / "force restart" — skip the already-running probe, stop any recorded instance, and start fresh
- **`--refresh`** / "regenerate" / "ignore the cached start-app docs" — force Mode 3 (Update): re-investigate and rewrite the cache
- **`--update`** / "my solution changed" — force Mode 3 seeded with the existing cache
- **anything else** — treated as a variant hint ("prod", "backend only", "rebuild", …) and matched against the cache's *Startup variants* table

Arguments passed to this command (if any): $ARGUMENTS
