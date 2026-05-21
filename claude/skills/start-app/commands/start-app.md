---
description: Start the application — uses the cached start intelligence at docs/framework/start-app.md when fresh, otherwise discovers startup scripts, selects the right one, executes it, and handles failures. Pass an optional prompt to target a specific stack or component (e.g. /start-app run the backend in prod mode), or pass --refresh to force a full re-investigation, --update to rewrite the cache after solution changes.
---

Use the `start-app` skill to start the application.

The skill always begins by checking `docs/framework/start-app.md` for a cached, confirmed start command for this solution. Pass `$ARGUMENTS` straight through so the skill can route to the right mode:

- **(no args)** — use the cache if fresh, otherwise generate it after a successful run
- **`--refresh`** / "regenerate" / "ignore the cached start-app docs" — force Mode 3 (Update): re-investigate and rewrite the cache
- **`--update`** / "my solution changed" — force Mode 3 seeded with the existing cache
- **anything else** — treated as a variant hint ("prod", "backend only", "rebuild", …) and matched against the cache's *Startup variants* table

Arguments passed to this command (if any): $ARGUMENTS
