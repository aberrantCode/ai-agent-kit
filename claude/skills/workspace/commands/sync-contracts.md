---
description: Lightweight incremental contract update — run frequently. Checks monitored contract source files for changes, updates CONTRACTS.md with the diff, and validates consistency, without re-running the full workspace analysis.
---

Apply the `workspace` skill and execute its **sync-contracts** operation.

1. Read `_project_specs/workspace/.contract-sources` (written by `/analyze-workspace`) and check each listed file for changes since the last sync.
2. For any changed source, re-extract its contract (endpoints, types, schemas) and update the corresponding section of `CONTRACTS.md` — refresh the `Last sync` timestamp and the `Contract Validation Status` table.
3. Validate consistency — e.g. endpoint counts in a generated spec (`openapi.json`) against what's documented in `CONTRACTS.md` — and flag drift as a warning rather than failing.
4. If `.contract-sources` is missing or no prior analysis exists, stop and recommend `/analyze-workspace` first. This operation is incremental only; it does not perform topology, dependency-graph, or key-file discovery.

This is the cheap pass (~15 sec) — run it after any change to a contract source (API schema, shared types, OpenAPI spec) and before pushing, per the skill's Freshness Tiers. For full topology/dependency/key-file re-discovery, use `/analyze-workspace` instead.
