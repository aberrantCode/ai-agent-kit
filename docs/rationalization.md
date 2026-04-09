# Skills Archive Rationalization Report

> **Date:** 2026-04-09
> **Scope:** 90 Claude skills across 10 categories
> **Status:** Analysis complete — awaiting implementation decisions

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Methodology](#methodology)
- [Findings by Category](#findings-by-category)
  - [UI & Design (8 skills)](#ui--design)
  - [Code Quality & Review (11 skills)](#code-quality--review)
  - [Workflow & Git (17 skills)](#workflow--git)
  - [Frameworks & Languages (9 skills)](#frameworks--languages)
  - [Databases (10 skills)](#databases)
  - [AI & LLM (3 skills)](#ai--llm)
  - [Content & Marketing (4 skills)](#content--marketing)
  - [Commerce (5 skills)](#commerce)
  - [Specialized & Niche (13+ skills)](#specialized--niche)
- [Consolidation Roadmap](#consolidation-roadmap)
- [Conflict Resolution](#conflict-resolution)
- [Skills to Deprecate or Archive](#skills-to-deprecate-or-archive)
- [Skills to Keep As-Is](#skills-to-keep-as-is)
- [Implementation Phases](#implementation-phases)

---

## Executive Summary

Analysis of all 90 Claude skills reveals:

| Metric | Count |
|--------|-------|
| Overlap zones identified | 28 |
| Direct conflicts | 8 |
| Merge candidates (recommended) | 12 |
| Skills flagged as too niche | 7 |
| Skills confirmed well-scoped | 45+ |

**Top-line recommendations:**

1. **Merge 12 skill pairs/groups** to eliminate ~40% of semantic duplication
2. **Resolve 8 conflicts** where skills give contradictory advice
3. **Relocate 5 project-specific skills** to project-local folders
4. **Archive 2 utility skills** that don't warrant standalone status
5. **Add cross-references** across 15+ skills that compose but don't document their relationships

**Net effect:** 90 skills would become ~72-75 focused, non-overlapping skills with clear dependency chains.

---

## Methodology

Five parallel analysis agents each examined a cluster of related skills:

1. **UI/Design cluster** — 8 skills compared pairwise
2. **Code Quality cluster** — 11 skills compared pairwise
3. **Workflow/Git cluster** — 17 skills compared pairwise
4. **Frameworks/Databases cluster** — 23 skills compared pairwise
5. **Content/Commerce/Niche cluster** — 26 skills compared pairwise

Each agent read the full SKILL.md content (not just frontmatter) and reported:
- **OVERLAP:** Semantic duplication between skills
- **CONFLICT:** Contradictory advice between skills
- **MERGE CANDIDATE:** Skills that should consolidate
- **TOO NICHE:** Skills that may not belong in a general archive

---

## Findings by Category

### UI & Design

**Skills analyzed:** design-taste-frontend, frontend-design, ui-web, ui-mobile, ui-testing, web-design-guidelines, user-journeys, pwa-development

#### Overlaps

| Skill A | Skill B | What Overlaps | Severity |
|---------|---------|---------------|----------|
| design-taste-frontend | frontend-design | Both cover high-quality interface creation, avoiding AI aesthetics | HIGH |
| ui-web | ui-testing | ui-testing duplicates contrast/sizing rules from ui-web | MEDIUM |
| ui-mobile | ui-testing | Same duplication pattern as ui-web | MEDIUM |
| design-taste-frontend | ui-web | Typography, color systems, spacing grids, dark mode, forms | MEDIUM |
| design-taste-frontend | web-design-guidelines | Both are web design rule sets (one self-contained, one fetches external) | MEDIUM |
| user-journeys | ui-testing | UX Validation Checklist duplicates ui-testing pre-flight checks | LOW |

#### Conflicts

| Skill A | Skill B | Contradiction |
|---------|---------|---------------|
| design-taste-frontend | ui-web | **Motion:** design-taste requires Framer Motion; ui-web uses CSS transitions |
| design-taste-frontend | ui-web | **Cards:** design-taste conditionally bans cards; ui-web recommends them as default |
| design-taste-frontend | ui-web | **Shadows:** design-taste bans box-shadow glows; ui-web uses shadow-lg throughout |

#### Merge Candidates

| # | Source Skills | Target | Rationale | Priority |
|---|-------------|--------|-----------|----------|
| M1 | design-taste-frontend + frontend-design | `production-frontend-design` | Both address same goal (distinctive UI); one prescriptive, one conceptual. Merge: conceptual thinking first, then specific rules | HIGH |
| M2 | ui-web + ui-testing (web portion) | `web-ui` | ui-testing is a thin validation wrapper over ui-web; merge validation checklist into implementation guide | MEDIUM |
| M3 | ui-mobile + ui-testing (mobile portion) | `mobile-ui` | Same logic as M2 for mobile platform | MEDIUM |
| M4 | web-design-guidelines | **ARCHIVE** | Thin wrapper (~40 lines) fetching external Vercel rules; redundant with design-taste-frontend | LOW |

#### Keep As-Is

- **pwa-development** — Distinct feature set (service workers, offline, installability)
- **user-journeys** — Different focus (journey mapping vs component design)
- **ui-web / ui-mobile** — Platform-specific; don't merge across platforms

---

### Code Quality & Review

**Skills analyzed:** code-review, codex-review, gemini-review, requesting-code-review, security, security-review, base, tdd-workflow, iterative-development, code-deduplication, subagent-driven-development

#### Overlaps

| Skill A | Skill B | What Overlaps | Severity |
|---------|---------|---------------|----------|
| code-review | codex-review / gemini-review | All three are code review with different engines; duplicate CI/CD integration | HIGH |
| security | security-review | 85% content overlap; security-review depends on security | HIGH |
| tdd-workflow | iterative-development | Both teach RED-GREEN-VALIDATE TDD cycle | HIGH |
| base | tdd-workflow | base mandates TDD; tdd-workflow elaborates it | MEDIUM |
| base | iterative-development | base Section "Ralph Wiggum" IS iterative-development | MEDIUM |
| code-review | requesting-code-review | Both review code before merge (automated vs subagent) | MEDIUM |
| subagent-driven-development | requesting-code-review | Both dispatch review subagents (different templates) | LOW |

#### Conflicts

| Skill A | Skill B | Contradiction |
|---------|---------|---------------|
| tdd-workflow | iterative-development | **Execution model:** Sequential steps vs looping cycles |
| code-review | base | **TDD integration:** code-review adds review step after tests; base doesn't include it |
| base | iterative-development | **Auto-invocation:** base says Ralph Wiggum is automatic; iterative-development shows it as optional |
| requesting-code-review | subagent-driven-development | **Review framework:** Different subagent templates for same function |

#### Merge Candidates

| # | Source Skills | Target | Rationale | Priority |
|---|-------------|--------|-----------|----------|
| M5 | security + security-review | `security` (unified) | Single source of truth; security-review already depends on security | HIGH |
| M6 | tdd-workflow + iterative-development | `test-driven-development` | Same TDD cycle; merge sequential + looped modes into one skill with comparison table | HIGH |
| M7 | codex-review + gemini-review | `code-review/engines/` sub-skills | Keep code-review as hub; move engine-specific docs to sub-skills | MEDIUM |
| M8 | code-review + requesting-code-review | `code-review` (add manual mode) | Single skill with automated + manual review modes | LOW |

---

### Workflow & Git

**Skills analyzed:** commit-hygiene, ship-to-dev, release-to-main, finishing-a-development-branch, git-cleanup, using-git-worktrees, publish-github, add-feature, create-feature-spec, feature-start, fix-start, pre-pr, retro-fit-spec, spec-align, project-manager, session-management, existing-repo

#### Overlaps

| Skill A | Skill B | What Overlaps | Severity |
|---------|---------|---------------|----------|
| add-feature | create-feature-spec | Both create feature specs with structured phases; identical output | HIGH |
| ship-to-dev | finishing-a-development-branch (Option 2) | Both create PRs, push, merge | MEDIUM |
| publish-github | existing-repo | Both initialize .gitignore, pre-commit hooks, branch conventions | MEDIUM |
| commit-hygiene | ship-to-dev / release-to-main | Commit format rules repeated in workflow skills | LOW |
| git-cleanup | finishing-branch (Option 4) | Both delete branches | LOW |

#### Conflicts

| Skill A | Skill B | Contradiction |
|---------|---------|---------------|
| finishing-a-development-branch (Option 1) | ship-to-dev | **Merge location:** finishing allows local merge; ship-to-dev requires PR-based merge |

#### Merge Candidates

| # | Source Skills | Target | Rationale | Priority |
|---|-------------|--------|-----------|----------|
| M9 | add-feature + create-feature-spec | `feature-spec-workflow` | Same goal, same output; add style selector (conversational vs template-first) | HIGH |
| M10 | finishing-a-development-branch | **REFACTOR** | Remove "local merge" option; delegate PR path to ship-to-dev | MEDIUM |

#### HomeRadar-Specific Skills (Keep Separate)

These 5 skills are appropriately project-specific:
- `homeradar-feature-start` — Entry point for HomeRadar features
- `homeradar-fix-start` — Bug fix classification with SEV levels
- `homeradar-pre-pr` — Pre-PR gates with CAP-ID enforcement
- `homeradar-retro-fit-spec` — Spec modernization (adding CAP-IDs)
- `homeradar-spec-align` — Full gap-fill workflow

**Recommendation:** Keep in archive but document the cluster relationship. Consider relocating to a `claude/skills/_homeradar/` subdirectory.

---

### Frameworks & Languages

**Skills analyzed:** react-web, react-native, react-best-practices, composition-patterns, nodejs-backend, typescript, python, flutter, chrome-extension-builder

#### Overlaps

| Skill A | Skill B | What Overlaps | Severity |
|---------|---------|---------------|----------|
| react-web | react-best-practices | Both address React performance, state management | MEDIUM |
| react-web | composition-patterns | Both address component architecture | LOW |
| typescript | react-web / nodejs-backend | Strict mode config, testing patterns (Jest) | LOW |

#### Conflicts

| Skill A | Skill B | Contradiction |
|---------|---------|---------------|
| react-best-practices | composition-patterns | Minor: memoization (perf) vs compound components (architecture) — not a true conflict, different concerns |

#### Merge Candidates

| # | Source Skills | Target | Rationale | Priority |
|---|-------------|--------|-----------|----------|
| — | react-best-practices → react-web | Add as "Performance" section | Users of react-web almost always need best-practices; consider merging or adding `requires:` | LOW |

#### Keep As-Is

All language/framework skills are well-scoped and platform-specific. No merges recommended beyond the react consideration.

---

### Databases

**Skills analyzed:** supabase, supabase-nextjs, supabase-node, supabase-python, database-schema, firebase, aws-aurora, aws-dynamodb, azure-cosmosdb, cloudflare-d1

#### Overlaps

| Skill A | Skill B | What Overlaps | Severity |
|---------|---------|---------------|----------|
| supabase | supabase-nextjs / supabase-node / supabase-python | ~70% duplication: RLS patterns, migration workflows, auth setup | CRITICAL |
| aws-dynamodb | azure-cosmosdb / firebase | Partition key strategy, transaction patterns, real-time listeners | MEDIUM |
| database-schema | All database skills | Schema/type generation repeated in each | MEDIUM |

#### Merge Candidates

| # | Source Skills | Target | Rationale | Priority |
|---|-------------|--------|-----------|----------|
| M11 | supabase + supabase-nextjs + supabase-node + supabase-python | `supabase` (core) + 3 integration sub-skills | Extract shared content (RLS, migrations, auth) into core; framework-specific patterns become sub-skills | HIGH |
| M12 | aws-dynamodb + azure-cosmosdb + firebase (partial) | Extract `nosql-patterns` | Shared partition key design, transaction patterns, real-time sync; database-specific skills reference it | MEDIUM |

#### Keep As-Is

- **aws-aurora / cloudflare-d1** — Well-differentiated (enterprise vs edge SQL)
- **firebase / supabase** — Different paradigms (NoSQL+sync vs SQL+RLS)
- **database-schema** — Keep as standalone reference, add to `requires:` of database skills

---

### AI & LLM

**Skills analyzed:** agentic-development, ai-models, llm-patterns

#### Overlaps

| Skill A | Skill B | What Overlaps | Severity |
|---------|---------|---------------|----------|
| agentic-development | llm-patterns | Both guide LLM-powered applications; agentic-development is a superset | MEDIUM |

#### Merge Candidates

| # | Source Skills | Target | Rationale | Priority |
|---|-------------|--------|-----------|----------|
| M13 | agentic-development + llm-patterns | `llm-application-patterns` | Merge into: "Foundational Patterns" (typed wrappers, prompts, testing) + "Agent Patterns" (tool-calling, planning, memory) | MEDIUM |

#### Keep As-Is

- **ai-models** — Reference data (model specs, pricing); no overlap with pattern skills

---

### Content & Marketing

**Skills analyzed:** aeo-optimization, site-architecture, web-content, doc-coauthoring

#### Overlaps

| Skill A | Skill B | What Overlaps | Severity |
|---------|---------|---------------|----------|
| aeo-optimization | web-content | Both optimize for AI discovery (AEO: semantic triples; GEO: schema markup) | HIGH |
| site-architecture | web-content | Both address on-page SEO factors | MEDIUM |

#### Merge Candidates

| # | Source Skills | Target | Rationale | Priority |
|---|-------------|--------|-----------|----------|
| M14 | aeo-optimization + web-content + site-architecture | `seo-and-ai-discovery` | Unified skill covering traditional SEO + GEO + AEO; avoids practitioners bouncing between three skills | MEDIUM |

---

### Commerce

**Skills analyzed:** klaviyo, medusa, shopify-apps, web-payments, woocommerce

**Assessment:** All five target different platforms with distinct APIs and toolchains. Despite touching similar domains (customer lifecycle, events, payments), they are **correctly separated** because developers choose one platform, not all five.

**Recommendation:** Keep all separate. Add cross-reference sections for integration points (e.g., "Klaviyo integrates with Shopify — see shopify-apps skill").

---

### Specialized & Niche

#### Too Niche for General Archive

| Skill | Issue | Recommendation |
|-------|-------|----------------|
| worldview-layer-scaffold | Specific to WorldView GEOINT dashboard | Move to project-specific folder or `_worldview/` subdirectory |
| worldview-shader-preset | Same as above | Merge with worldview-layer-scaffold → `worldview-extensions`; move to project-specific |
| youtube-prd-forensics | Extremely specific video-to-PRD workflow | Generalize to "video-to-documentation" or move to project docs |
| feature-start (homeradar) | HomeRadar-specific | Keep but relocate to `_homeradar/` subdirectory |
| fix-start (homeradar) | HomeRadar-specific | Same as above |
| pre-pr (homeradar) | HomeRadar-specific | Same as above |
| retro-fit-spec (homeradar) | HomeRadar-specific | Same as above |
| spec-align (homeradar) | HomeRadar-specific | Same as above |

#### Marginal Niche (Keep but Monitor)

| Skill | Assessment |
|-------|-----------|
| logo-restylizer | Narrow utility (logo variants); useful but infrequent |
| explain-code | More of a technique than a task skill; consider folding into best practices |
| start-app | Shell-scripting convenience; developers typically use their package manager directly |
| team-coordination | Organization-specific coordination model; may not translate across teams |

#### Well-Scoped Standalone Skills (No Action)

| Skill | Why It's Fine |
|-------|--------------|
| ms-teams-apps | Platform-specific (Teams bots); distinct from general agent patterns |
| posthog-analytics | Analytics-specific; no overlap with other marketing skills |
| playwright-testing | E2E testing specialist; complements but doesn't overlap ui-testing |
| guide-assistant | Interactive step-by-step guidance; distinct from doc-coauthoring |
| chrome-extension-builder | Chrome MV3 extensions; specialized enough to warrant standalone |
| credentials | API key management from Access.txt; narrow and essential |
| workspace | Multi-repo topology analysis; distinct from team-coordination |

---

## Consolidation Roadmap

### Summary of All Merge Candidates

| ID | Source Skills | Target | Category | Priority | Difficulty | Risk |
|----|-------------|--------|----------|----------|------------|------|
| M1 | design-taste-frontend + frontend-design | `production-frontend-design` | UI | HIGH | Medium | Low |
| M2 | ui-web + ui-testing (web) | `web-ui` | UI | MEDIUM | Low | Low |
| M3 | ui-mobile + ui-testing (mobile) | `mobile-ui` | UI | MEDIUM | Low | Low |
| M4 | web-design-guidelines | **ARCHIVE** | UI | LOW | Low | Low |
| M5 | security + security-review | `security` (unified) | Quality | HIGH | Medium | Medium |
| M6 | tdd-workflow + iterative-development | `test-driven-development` | Quality | HIGH | High | Medium |
| M7 | codex-review + gemini-review | sub-skills of code-review | Quality | MEDIUM | Low | Low |
| M8 | code-review + requesting-code-review | `code-review` (add manual mode) | Quality | LOW | Medium | Low |
| M9 | add-feature + create-feature-spec | `feature-spec-workflow` | Workflow | HIGH | Medium | Low |
| M10 | finishing-a-development-branch | **REFACTOR** (remove local merge) | Workflow | MEDIUM | Low | Low |
| M11 | supabase × 4 | `supabase` core + 3 integration sub-skills | Databases | HIGH | High | Medium |
| M12 | dynamodb + cosmosdb + firebase | Extract `nosql-patterns` | Databases | MEDIUM | High | Medium |
| M13 | agentic-development + llm-patterns | `llm-application-patterns` | AI | MEDIUM | Medium | Low |
| M14 | aeo-optimization + web-content + site-architecture | `seo-and-ai-discovery` | Content | MEDIUM | Medium | Low |

---

## Conflict Resolution

| # | Conflict | Resolution |
|---|----------|------------|
| C1 | design-taste-frontend vs ui-web on motion (Framer Motion vs CSS transitions) | Resolve during M1 merge; use CSS transitions as default, Framer Motion for complex interactions |
| C2 | design-taste-frontend vs ui-web on cards (banned vs recommended) | Resolve during M1 merge; cards are default, ban only for explicitly high-density layouts |
| C3 | design-taste-frontend vs ui-web on shadows | Resolve during M1 merge; allow subtle shadows (shadow-sm/md), ban outer glow effects |
| C4 | tdd-workflow vs iterative-development execution model | Resolve during M6 merge; document both modes with "when to use each" guidance |
| C5 | base auto-invocation of Ralph Wiggum vs iterative-development optional | Resolve during M6 merge; make explicit: auto for non-trivial tasks, optional for simple fixes |
| C6 | code-review vs base TDD step order | Add code-review as optional step in TDD workflow; mandatory before commit |
| C7 | requesting-code-review vs subagent-driven-development review templates | Resolve during M8; standardize on one review subagent framework |
| C8 | finishing-a-development-branch local merge vs ship-to-dev PR merge | Resolve via M10; remove local merge option |

---

## Skills to Deprecate or Archive

| Skill | Action | Reason |
|-------|--------|--------|
| web-design-guidelines | `status: deprecated` | Thin wrapper; redundant with design-taste-frontend |
| ui-testing (as standalone) | **Absorb** into ui-web and ui-mobile | Not independently useful; always loaded with a UI skill |

---

## Skills to Keep As-Is

These 45+ skills are well-scoped, non-overlapping, and correctly positioned:

**Languages:** python, typescript, flutter, android-java, android-kotlin, react-native, react-web, nodejs-backend

**Databases:** aws-aurora, aws-dynamodb, azure-cosmosdb, cloudflare-d1, firebase, database-schema

**Workflow:** commit-hygiene, ship-to-dev, release-to-main, git-cleanup, using-git-worktrees, publish-github, project-manager, session-management, existing-repo

**Commerce:** klaviyo, medusa, shopify-apps, web-payments, woocommerce

**Specialized:** chrome-extension-builder, ms-teams-apps, posthog-analytics, playwright-testing, pwa-development, guide-assistant, credentials, workspace, ai-models, visual-explainer, logo-restylizer, reddit-ads, reddit-api, doc-coauthoring, vercel-deploy

**Quality:** base, code-deduplication, subagent-driven-development

---

## Implementation Phases

### Phase 1 — High Priority, Low Risk (Do First)

| Action | Skills | Expected Outcome |
|--------|--------|-----------------|
| M1: Merge frontend design skills | design-taste-frontend + frontend-design | 1 unified skill with conceptual + prescriptive guidance |
| M5: Merge security skills | security + security-review | 1 unified security skill; eliminate 85% duplication |
| M9: Merge feature spec skills | add-feature + create-feature-spec | 1 skill with style selector (conversational vs template) |
| M10: Refactor finishing-branch | finishing-a-development-branch | Remove local merge option; delegate to ship-to-dev |

**Estimated reduction:** 90 → 86 skills

### Phase 2 — High Priority, Medium Risk

| Action | Skills | Expected Outcome |
|--------|--------|-----------------|
| M6: Merge TDD skills | tdd-workflow + iterative-development | 1 unified TDD skill with sequential + looped modes |
| M11: Restructure Supabase | supabase × 4 | 1 core skill + 3 integration sub-skills (net: same count, 70% less duplication) |
| M2/M3: Absorb ui-testing | ui-testing → ui-web + ui-mobile | Validation checklists merged into platform UI skills |
| Resolve C1-C3 | design-taste vs ui-web conflicts | Unified motion/cards/shadows guidance |

**Estimated reduction:** 86 → 82 skills

### Phase 3 — Medium Priority

| Action | Skills | Expected Outcome |
|--------|--------|-----------------|
| M7: Engine sub-skills | codex-review + gemini-review → code-review sub-skills | Cleaner hierarchy |
| M12: Extract NoSQL patterns | dynamodb + cosmosdb + firebase | New shared skill; reduce 40% redundancy |
| M13: Merge LLM skills | agentic-development + llm-patterns | 1 unified LLM application patterns skill |
| M14: Merge SEO/content | aeo + web-content + site-architecture | 1 unified SEO & AI discovery skill |
| M4: Archive web-design-guidelines | web-design-guidelines → deprecated | Remove redundant thin wrapper |

**Estimated reduction:** 82 → 75 skills

### Phase 4 — Housekeeping

| Action | Skills | Expected Outcome |
|--------|--------|-----------------|
| Relocate HomeRadar skills | 5 homeradar-* skills | Move to `_homeradar/` subdirectory |
| Relocate WorldView skills | 2 worldview-* skills | Move to `_worldview/` subdirectory |
| Add cross-references | 15+ skills | Document dependency chains and composition patterns |
| Generalize youtube-prd-forensics | 1 skill | Rename to `video-to-prd` or move to project docs |

**Final estimated count:** ~75 focused skills + project-specific subdirectories

---

## Appendix: Cross-Reference Map

Skills that compose together but don't currently document the relationship:

```
base ──requires──▶ tdd-workflow ──requires──▶ iterative-development
                  ──requires──▶ code-deduplication
                  ──requires──▶ code-review

security ──requires──▶ security-review
         ──used-by──▶ firebase, publish-github, existing-repo

commit-hygiene ──referenced-by──▶ ship-to-dev, release-to-main, pre-pr

react-web ──requires──▶ react-best-practices
          ──optional──▶ composition-patterns
          ──used-by──▶ ui-web, chrome-extension-builder

supabase ──requires──▶ supabase-nextjs | supabase-node | supabase-python

using-git-worktrees ──called-by──▶ feature-start, spec-align

database-schema ──should-require──▶ all database skills
```
