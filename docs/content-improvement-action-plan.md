# Action Plan for Follow-on Agent: Documentation Improvement Program

> Objective: Improve repository documentation alignment with peer-project best practices while preserving current archive structure and conventions.

## Phase 1 — Information Architecture (High Priority)

### Tasks
1. Split top-level docs by audience:
   - `docs/quick-start.md` (install/use)
   - `docs/contributor-guide.md` (authoring/updating skills)
   - `docs/maintainer-guide.md` (release, governance, parity checks)
2. Refactor root `README.md` into a concise routing page:
   - short project definition
   - quick install paths
   - links to the three audience docs above
   - compact inventory summary with links to detailed indexes
3. Add explicit troubleshooting entrypoint:
   - install failures
   - update path conflicts
   - verification commands

### Acceptance criteria
- New contributors can identify the correct guide in <= 30 seconds.
- README first screen contains no large skill table.
- Troubleshooting section exists and links to concrete commands.

## Phase 2 — Metadata and Quality Contract Documentation (High Priority)

### Tasks
1. Add `docs/manifest-contract.md` documenting:
   - `manifest.json` structure
   - generation source (`scripts/generate-manifest.py`)
   - expected stable fields vs generated metadata
2. Add a "maintenance checks" section to maintainer docs:
   - manifest regeneration command
   - parity checks expected before PR merge
3. Add clear frontmatter authoring checklist for skill maintainers.

### Acceptance criteria
- Manifest fields and purpose are documented in one canonical file.
- Maintainers have copy/paste-ready command snippets for routine checks.
- Skill authors can validate minimum frontmatter requirements without guessing.

## Phase 3 — Governance and Consolidation Surfacing (Medium Priority)

### Tasks
1. Surface `docs/rationalization.md` outcomes in maintainer workflow.
2. Add overlap/conflict triage guidance:
   - when to merge skills
   - when to deprecate
   - when to cross-reference only
3. Add migration notes for deprecated or overlapping skill paths where relevant.

### Acceptance criteria
- Rationalization analysis is discoverable from README or maintainer guide.
- Overlap decisions follow a documented triage rule set.
- Deprecation/migration decisions are visible to maintainers and users.

## Phase 4 — Discoverability and Navigation Enhancements (Medium Priority)

### Tasks
1. Create (or improve) skill index docs by category with links.
2. Add "See also" related-skill links for high-overlap domains.
3. Provide a compact navigation map of key operational commands.

### Acceptance criteria
- Users can discover related skills without scanning the full README table.
- Category-level navigation is available from one index page.
- Command discovery no longer depends on reading full root README.

## Suggested implementation sequence

1. Build docs skeleton (Phase 1 file set).
2. Move existing README sections into targeted docs with minimal rewriting.
3. Add contract/governance pages (Phases 2-3).
4. Add cross-linking and navigation polish (Phase 4).
5. Final pass: link integrity + readability + command accuracy.

## Non-goals for follow-on agent

- Do not change skill content semantics in this doc-refresh pass.
- Do not alter installer behavior.
- Do not modify manifest generation logic unless documentation reveals factual mismatch.

## Deliverables checklist

- [ ] `docs/quick-start.md`
- [ ] `docs/contributor-guide.md`
- [ ] `docs/maintainer-guide.md`
- [ ] `docs/manifest-contract.md`
- [ ] Updated concise root `README.md` (routing-first)
- [ ] Added troubleshooting guidance
- [ ] Added governance/consolidation linkage
- [ ] Updated internal cross-links
