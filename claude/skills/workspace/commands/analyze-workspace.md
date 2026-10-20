---
description: Full workspace analysis — run on first setup or major changes. Discovers workspace topology, maps the dependency graph, extracts API contracts, and identifies key files per context, writing all artifacts to `_project_specs/workspace/`.
---

Apply the `workspace` skill and execute its **analyze-workspace** operation.

Run the full Analysis Protocol end-to-end:

1. **Topology Discovery** — classify the workspace (monorepo / multi-repo / hybrid / single), list all modules/apps/packages, detect tech stack and entry points per module.
2. **Dependency Graph** — map internal imports, API call relationships, and database connections between modules.
3. **Contract Extraction** — detect and parse API contracts (OpenAPI, GraphQL, tRPC, Protobuf, TypeScript types, Pydantic, Zod), prioritizing generated specs and schema definitions as the source of truth.
4. **Key File Identification** — identify the files to load for each working context (route definitions, type definitions, config, entry points, API clients, database schema), tagged by token priority.

Write all six generated artifacts to `_project_specs/workspace/`: `TOPOLOGY.md`, `CONTRACTS.md`, `DEPENDENCY_GRAPH.md`, `KEY_FILES.md`, `CROSS_REPO_INDEX.md`, and `.contract-sources` (the list of contract-defining files to monitor for staleness). Follow the formats documented in the skill's "Generated Artifacts" section exactly.

This is the expensive, full pass (~2 min) — run it on first setup of a workspace or after major structural changes (new module, new repo, workspace reorg). For routine contract-only updates once this has already run, use `/sync-contracts` instead.
