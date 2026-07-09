---
name: scanner-plugin-integration
description: Use when importing, fixing, or adding a new provider/scanner plugin (e.g. OSINT lookup services, external-API integrations) into an existing Go-style package tree — merge orphaned scaffolds into the real package, preserve the plugin interface pattern, keep gating in DryRun not Run, and verify live endpoints before coding against docs.
status: active
version: 2026-07-05
---

# Scanner Plugin Integration

## When to use

You're integrating a set of similar external-service plugins (scanners, providers, suppliers — any "one interface, many implementations" integration) into a codebase, especially when: the code was scaffolded in a separate location and needs merging into the real package tree, you're adding a new provider that should follow an established plugin template, or you're fixing/decommissioning an existing provider.

## Method

### Fixing orphaned scaffolds (Go-specific but broadly applicable)
1. **Know that package identity is the *directory*, not the `package` clause.** If scanner code lives in a separate top-level folder (e.g., `phoneinfoga-breach/lib/remote/`) instead of the real package tree, Go treats it as a distinct package even if the `package` clause names match. This causes import failures like `undefined: suppliers.DehashedSupplierInterface`.
2. **Fix by moving, not re-exporting.** Move the files into the real tree (`lib/remote/`, `lib/remote/suppliers/`, `mocks/`), merge registration into the tree's existing `init.go`, and delete the scaffold entirely. Don't leave a re-export shim — that just relocates the confusion.
3. This applies to any "sidecar extraction that should have been integrated into the main package" — the fix pattern (merge directories, consolidate init/registration, delete the orphan) generalizes beyond this one case.

### Preserving the plugin interface pattern
4. **When importing multiple similar provider integrations, identify and preserve the common shape**: a small fixed-method interface (e.g., 4 methods), a supplier-delegation layer, a mock implementation, and table-driven tests — applied consistently across every provider instance.
5. Keeping this shape consistent means adding a future provider is templating against the existing pattern, not a bespoke one-off implementation each time.

### Gating architecture
6. **Put gating (credential/flag validation) in `DryRun()`, not `Run()`.** The orchestration layer (e.g., `Library.Scan`) calls `DryRun()` first for every registered scanner and skips any that fail — enforcing the gate at the aggregate level. Each scanner's `Run()` stays a thin "just do the work" method with no validation logic duplicated inside it.
7. **Expose the same gate to the frontend via an HTTP `/dryrun` endpoint.** A separate `/run` endpoint deliberately bypasses the gate — it assumes the caller already checked `/dryrun` — so don't add redundant validation inside `/run`; that's the orchestration layer's job.

### Adding or fixing a provider
8. Before writing code: **understand the supplier interface** (method signatures like `SearchByPhone`, expected response shape).
9. **Test the live endpoint first** to confirm exact URL, auth mechanism, and response format — don't trust vendor docs, they drift from the actual API.
10. **Keep interfaces mock-friendly** so tests run without live credentials — this is why the 4-method interface + mock pattern from step 4 matters.
11. **Dedup response handlers across API versions** — e.g., when migrating a provider from v1 to v2, reuse existing response structs (`DehashedEntry`) instead of creating parallel v2-specific types.
12. **Decommissioning a provider means removing it completely**: delete backend files + role, remove registration, delete UI branches referencing it, clean docs, bump `.env.example`, and run the full test suite to confirm nothing references the removed provider.

## Gotchas

- A Go package with a matching `package` clause but a different directory is still a *different package* to the compiler — directory location, not the clause, is identity. This produces confusing "undefined" errors that look like a missing import, not a package-split problem.
- Don't put gating logic in `Run()` "for safety" — it duplicates the aggregate-level check in `DryRun()` and creates two sources of truth for whether a scanner should execute.
- Vendor/API docs go stale — always confirm exact URL/auth/response shape against the live endpoint before writing integration code, not after tests fail.
- Decommissioning is easy to do partially (delete the backend file but forget the UI branch or `.env.example` entry) — treat it as a checklist, not a single deletion.

## Diagram

[View diagram](diagram.html)
