# AI Agent Kit

A kit of reusable agent extensions — skills, agent instructions, and slash commands (with status lines and prompts on the way) — for **Claude Code**, **OpenAI Codex CLI**, and **Google Gemini CLI**.

---

## Quick Start

Deploy skills and instructions to your local profile with a single command:

```powershell
irm 'https://raw.githubusercontent.com/aberrantCode/ai-agent-kit/main/install-skills.ps1' | iex
```

The interactive installer walks you through:

1. **Platform** — Claude, Codex, and/or Gemini
2. **Asset type** — Skills, Instructions, or both
3. **Deploy paths** — where to install (defaults provided per platform)
4. **Selection** — collapsible category browser with per-item descriptions

Requires PowerShell 5.1+. Works on Windows, macOS (`pwsh`), and Linux (`pwsh`).

---

## What's Inside

```
ai-agent-kit/
├── claude/
│   ├── instructions/     # 15 agent instructions
│   ├── commands/         # 27 slash commands
│   └── skills/           # 91 domain-specific knowledge modules
├── codex/
│   ├── instructions/     # Agent instructions for Codex CLI
│   └── skills/           # 90 domain-specific knowledge modules
├── gemini/
│   ├── instructions/     # Agent instructions for Gemini CLI
│   └── skills/           # 5 domain-specific knowledge modules
└── install-skills.ps1    # Remote interactive installer
```

| Type | Claude | Codex | Gemini | Total |
|------|:------:|:-----:|:------:|------:|
| Skills | 107 | 90 | 5 | 202 |
| Instructions | 15 | — | — | 15 |
| Commands | 27 | — | — | 27 |

---

## Installation

### Remote installer (recommended)

The one-liner above fetches the installer from GitHub and runs it interactively. It uses the GitHub API to list available assets and downloads only what you select.

**Default deploy paths:**

| Platform | Skills | Instructions |
|----------|--------|--------------|
| Claude | `~/.claude/skills/` | `~/.claude/agents/` |
| Codex | `~/.codex/skills/` | `~/.codex/agents/` |
| Gemini | `~/.gemini/skills/` | `~/.gemini/agents/` |

All paths are prompted at runtime — press Enter to accept the default or type a custom path.

**What gets installed per skill:**

| File | Required | Description |
|------|:--------:|-------------|
| `SKILL.md` | yes | Main skill content |
| `commands/*.md` | no | Companion slash commands |
| `sub-skills/*/SKILL.md` | no | Delegate sub-skills |
| `references/**` | no | Skill-local templates and support files |
| `rules/**` | no | Skill-local rule libraries (e.g. Vercel react-best-practices) |

Instructions are single `.md` files — no bundles.

### Manual install

Clone the repo and copy what you need:

```bash
git clone https://github.com/aberrantCode/ai-agent-kit.git
cp -r ai-agent-kit/claude/skills/typescript ~/.claude/skills/typescript
cp ai-agent-kit/claude/instructions/architect.md ~/.claude/agents/architect.md
```

### Archive management commands

If you have the `skills-manager` skill installed, these slash commands manage the archive itself:

| Command | Purpose |
|---------|---------|
| `/search-skill <query>` | Keyword search across the archive |
| `/install-skill <name>` | Deploy a skill bundle to a project |
| `/update-skill` | Update installed skills to latest archive versions |
| `/audit-skills` | Full archive health check (read-only) |
| `/find-skills` | Discover new/changed skills on workstation |
| `/sync-skill <name>` | Archive a skill from its source location |
| `/import-skill <name>` | Pull project-level changes back to archive |
| `/push-skill <name>` | Push skill bundle to global `~/.claude/skills/` |
| `/backfill-diagrams` | Generate missing `diagram.html` files |

---

## Skills

Domain-specific knowledge modules loaded into AI context. Each skill lives in `{platform}/skills/{name}/SKILL.md`.

**Categories at a glance:**

| Category | Count | Examples |
|----------|:-----:|---------|
| Foundations & Workflow | 25 | base, tdd-workflow, **github** (`/merge`), analyze-conversations, **what-next** |
| Languages & Runtimes | 4 | typescript, python, nodejs-backend, marko |
| Frontend Frameworks | 8 | react-web, flutter, chrome-extension-builder |
| Mobile (Native) | 3 | android-java, android-kotlin, ui-mobile |
| UI & Design | 9 | ui-web, frontend-design, visual-explainer |
| Databases & Storage | 10 | supabase, firebase, aws-dynamodb, cloudflare-d1 |
| Code Quality | 6 | code-review, codex-review, gemini-review, playwright-testing |
| Security & Credentials | 4 | security, credentials, security-review, sops-secrets |
| AI & LLM | 6 | agentic-development, llm-patterns, ai-models, csv-driven-llm-pipeline, honcho, project-manager |
| Commerce & Payments | 4 | shopify-apps, medusa, web-payments, woocommerce |
| Third-Party Integrations | 5 | klaviyo, reddit-api, ms-teams-apps, posthog-analytics |
| SEO & Web Presence | 3 | site-architecture, web-content, aeo-optimization |
| Tooling & DevOps | 12 | ac-opbta-ops, project-tooling, publish-github, skills-manager, start-app, graphify |
| Research & OSINT | 12 | youtube-extraction, youtube-prd-forensics, worldview-layer-scaffold |

<details>
<summary><strong>Full skill list (139 Claude skills)</strong></summary>

| Skill | Category | Description | Claude | Codex | Gemini |
|-------|----------|-------------|:------:|:-----:|:------:|
| [`base`](claude/skills/base/) | Foundations & Workflow | Universal coding patterns, constraints, TDD workflow, and atomic todos | ✓ | ✓ | |
| [`iterative-development`](claude/skills/iterative-development/) | Foundations & Workflow | Self-referential TDD iteration — cycles until tests pass | ✓ | ✓ | |
| [`session-management`](claude/skills/session-management/) | Foundations & Workflow | Context preservation, tiered summarization, and resumability | ✓ | ✓ | |
| [`analyze-conversations`](claude/skills/analyze-conversations/) | Foundations & Workflow | Mine Claude Code session transcripts for recurring mistakes and friction, then propose prevention patches (ships bundled extractor) | ✓ | | |
| [`team-coordination`](claude/skills/team-coordination/) | Foundations & Workflow | Multi-person projects — shared state, todo claiming, handoffs | ✓ | ✓ | |
| [`existing-repo`](claude/skills/existing-repo/) | Foundations & Workflow | Analyze existing repositories, maintain structure, setup guardrails | ✓ | ✓ | |
| [`subagent-driven-development`](claude/skills/subagent-driven-development/) | Foundations & Workflow | Parallel task execution using sub-agents | ✓ | ✓ | |
| [`create-feature-spec`](claude/skills/create-feature-spec/) | Foundations & Workflow | Create feature specifications from a single sentence | ✓ | ✓ | |
| [`finishing-a-development-branch`](claude/skills/finishing-a-development-branch/) | Foundations & Workflow | Guides branch completion — merge, PR, squash, or cleanup | ✓ | ✓ | |
| [`using-git-worktrees`](claude/skills/using-git-worktrees/) | Foundations & Workflow | Isolated git worktrees with smart directory selection | ✓ | ✓ | |
| [`requesting-code-review`](claude/skills/requesting-code-review/) | Foundations & Workflow | Dispatch code review before merging | ✓ | ✓ | |
| [`github`](claude/skills/github/) | Foundations & Workflow | Git/GitHub thin-command bundle — `/publish-github`, `/commit`, `/ship-to-dev`, `/merge`, `/release-to-main`, `/git-cleanup` with a minimal-output contract | ✓ | | |
| [`ship-to-dev`](claude/skills/ship-to-dev/) | Foundations & Workflow | _Deprecated — folded into `github`._ Feature branch → DEV merge workflow with test gates | ✓ | ✓ | |
| [`release-to-main`](claude/skills/release-to-main/) | Foundations & Workflow | _Deprecated — folded into `github`._ DEV → main release with semantic versioning and tagging | ✓ | ✓ | |
| [`commit-hygiene`](claude/skills/commit-hygiene/) | Foundations & Workflow | Atomic commits, PR size limits, commit thresholds | ✓ | ✓ | |
| [`git-cleanup`](claude/skills/git-cleanup/) | Foundations & Workflow | _Deprecated — folded into `github`._ Audit and remove stale worktrees and merged branches | ✓ | ✓ | |
| [`guide-assistant`](claude/skills/guide-assistant/) | Foundations & Workflow | Walk through any markdown guide step-by-step | ✓ | ✓ | |
| [`feature-start`](claude/skills/feature-start/) | Foundations & Workflow | Pre-flight workflow before starting feature work | ✓ | ✓ | |
| [`fix-start`](claude/skills/fix-start/) | Foundations & Workflow | Bug fix workflow with severity classification | ✓ | ✓ | |
| [`pre-pr`](claude/skills/pre-pr/) | Foundations & Workflow | Three self-gates before opening a pull request | ✓ | ✓ | |
| [`retro-fit-spec`](claude/skills/retro-fit-spec/) | Foundations & Workflow | Add capability IDs to feature specs missing them | ✓ | ✓ | |
| [`spec-align`](claude/skills/spec-align/) | Foundations & Workflow | Align codebase to a feature spec — gap analysis through implementation | ✓ | ✓ | |
| [`add-feature`](claude/skills/add-feature/) | Foundations & Workflow | Standalone conversational feature spec workflow; defers to project-manager:add-feature inside project-manager repositories | ✓ | ✓ | |
| [`what-next`](claude/skills/what-next/) | Foundations & Workflow | Universal next-action decider — detects the PM framework, prioritises pending work, delegates to the right specialist. Ships with [solution](claude/skills/what-next/diagrams/solution.html) / [feature](claude/skills/what-next/diagrams/features.html) / [plan](claude/skills/what-next/diagrams/plan.html) diagrams and a reusable [eval harness](claude/skills/what-next/evals/). | ✓ | | |
| [`code-deduplication`](claude/skills/code-deduplication/) | Foundations & Workflow | Prevent semantic duplication with capability index | ✓ | ✓ | |
| [`typescript`](claude/skills/typescript/) | Languages & Runtimes | TypeScript strict mode with eslint and jest | ✓ | ✓ | |
| [`python`](claude/skills/python/) | Languages & Runtimes | Python with ruff, mypy, pytest — TDD and type safety | ✓ | ✓ | |
| [`marko`](claude/skills/marko/) | Languages & Runtimes | Template engine and component system for node.js | ✓ | ✓ |  |
| [`nodejs-backend`](claude/skills/nodejs-backend/) | Languages & Runtimes | Node.js backend patterns with Express/Fastify | ✓ | ✓ | |
| [`react-web`](claude/skills/react-web/) | Frontend Frameworks | React web with hooks, React Query, Zustand | ✓ | ✓ | |
| [`react-native`](claude/skills/react-native/) | Frontend Frameworks | React Native and Expo — FlashList, Reanimated, React Compiler, native UI primitives, platform-specific code | ✓ | ✓ | |
| [`flutter`](claude/skills/flutter/) | Frontend Frameworks | Flutter with Riverpod, Freezed, go_router, mocktail | ✓ | ✓ | |
| [`pwa-development`](claude/skills/pwa-development/) | Frontend Frameworks | Progressive Web Apps — service workers, caching, Workbox | ✓ | ✓ | |
| [`chrome-extension-builder`](claude/skills/chrome-extension-builder/) | Frontend Frameworks | Chrome MV3 extensions with WXT + React + TypeScript | ✓ | ✓ | ✓ |
| [`composition-patterns`](claude/skills/composition-patterns/) | Frontend Frameworks | React composition patterns that scale — ships a 10-rule library | ✓ | ✓ | |
| [`react-best-practices`](claude/skills/react-best-practices/) | Frontend Frameworks | React/Next.js performance optimization from Vercel Engineering — ships a 57-rule library | ✓ | ✓ | |
| [`android-java`](claude/skills/android-java/) | Mobile (Native) | Android Java with MVVM, ViewBinding, Espresso | ✓ | ✓ | |
| [`android-kotlin`](claude/skills/android-kotlin/) | Mobile (Native) | Android Kotlin with Coroutines, Jetpack Compose, Hilt | ✓ | ✓ | |
| [`ui-mobile`](claude/skills/ui-mobile/) | Mobile (Native) | Mobile UI patterns — touch targets, platform conventions | ✓ | ✓ | |
| [`ui-web`](claude/skills/ui-web/) | UI & Design | Web UI — glassmorphism, Tailwind, dark mode, accessibility | ✓ | ✓ | |
| [`ui-testing`](claude/skills/ui-testing/) | UI & Design | Visual testing — invisible buttons, broken layouts, contrast | ✓ | ✓ | |
| [`design-taste-frontend`](claude/skills/design-taste-frontend/) | UI & Design | Senior UI/UX guidance with metric-based rules | ✓ | ✓ | |
| [`frontend-design`](claude/skills/frontend-design/) | UI & Design | Production-grade interfaces avoiding generic AI aesthetics | ✓ | ✓ | |
| [`logo-restylizer`](claude/skills/logo-restylizer/) | UI & Design | Restylize logos — dark/light/neon/flat variants | ✓ | ✓ | |
| [`user-journeys`](claude/skills/user-journeys/) | UI & Design | UX flows — journey mapping, validation, error recovery | ✓ | ✓ | |
| [`web-design-guidelines`](claude/skills/web-design-guidelines/) | UI & Design | Web Interface Guidelines compliance and UX audits | ✓ | ✓ | |
| [`doc-coauthoring`](claude/skills/doc-coauthoring/) | UI & Design | Structured co-authoring for docs and proposals | ✓ | ✓ | |
| [`explain-code`](claude/skills/explain-code/) | UI & Design | Explain code with visual diagrams and analogies | ✓ | ✓ | |
| [`visual-explainer`](claude/skills/visual-explainer/) | UI & Design | Generate self-contained HTML diagrams and reviews | ✓ | ✓ | |
| [`supabase`](claude/skills/supabase/) | Databases & Storage | Core Supabase CLI, migrations, RLS, Edge Functions | ✓ | ✓ | |
| [`supabase-nextjs`](claude/skills/supabase-nextjs/) | Databases & Storage | Next.js with Supabase and Drizzle ORM | ✓ | ✓ | |
| [`supabase-node`](claude/skills/supabase-node/) | Databases & Storage | Express/Hono with Supabase and Drizzle ORM | ✓ | ✓ | |
| [`supabase-python`](claude/skills/supabase-python/) | Databases & Storage | FastAPI with Supabase and SQLAlchemy/SQLModel | ✓ | ✓ | |
| [`firebase`](claude/skills/firebase/) | Databases & Storage | Firestore, Auth, Storage, real-time listeners | ✓ | ✓ | |
| [`aws-aurora`](claude/skills/aws-aurora/) | Databases & Storage | Aurora Serverless v2, RDS Proxy, Data API | ✓ | ✓ | |
| [`aws-dynamodb`](claude/skills/aws-dynamodb/) | Databases & Storage | DynamoDB single-table design, GSI patterns | ✓ | ✓ | |
| [`azure-cosmosdb`](claude/skills/azure-cosmosdb/) | Databases & Storage | Cosmos DB partition keys, consistency levels, change feed | ✓ | ✓ | |
| [`cloudflare-d1`](claude/skills/cloudflare-d1/) | Databases & Storage | Cloudflare D1 SQLite with Workers and Drizzle ORM | ✓ | ✓ | |
| [`database-schema`](claude/skills/database-schema/) | Databases & Storage | Schema awareness — read before coding, type generation | ✓ | ✓ | |
| [`code-review`](claude/skills/code-review/) | Code Quality | Mandatory reviews via `/code-review` before commits | ✓ | ✓ | |
| [`codex-review`](claude/skills/codex-review/) | Code Quality | OpenAI Codex CLI review with CI/CD integration | ✓ | ✓ | |
| [`gemini-review`](claude/skills/gemini-review/) | Code Quality | Gemini CLI review with 1M token context | ✓ | ✓ | |
| [`playwright-testing`](claude/skills/playwright-testing/) | Code Quality | E2E testing with Playwright — Page Objects, CI/CD | ✓ | ✓ | |
| [`tdd-workflow`](claude/skills/tdd-workflow/) | Code Quality | TDD Red/Green/Refactor with 80%+ coverage | ✓ | ✓ | ✓ |
| [`security`](claude/skills/security/) | Security & Credentials | OWASP patterns, secrets management, security testing | ✓ | ✓ | |
| [`credentials`](claude/skills/credentials/) | Security & Credentials | Centralized API key management from Access.txt | ✓ | ✓ | |
| [`security-review`](claude/skills/security-review/) | Security & Credentials | OWASP Top 10 checklist for auth, input, payments | ✓ | ✓ | ✓ |
| [`sops-secrets`](claude/skills/sops-secrets/) | Security & Credentials | SOPS-encrypted secrets — reading service logins, rotating credentials, KeePass sync | ✓ | | |
| [`agentic-development`](claude/skills/agentic-development/) | AI & LLM | Build AI agents with Pydantic AI and Claude SDK | ✓ | ✓ | |
| [`llm-patterns`](claude/skills/llm-patterns/) | AI & LLM | AI-first application patterns and prompt management | ✓ | ✓ | |
| [`ai-models`](claude/skills/ai-models/) | AI & LLM | Latest AI models reference — Claude, OpenAI, Gemini | ✓ | ✓ | |
| [`csv-driven-llm-pipeline`](claude/skills/csv-driven-llm-pipeline/) | AI & LLM | Stateful, resumable CSV-driven batch pipelines mixing HTTP fetch and LLM calls with per-row state | ✓ | | |
| [`honcho`](claude/skills/honcho/) | AI & LLM | Honcho AI-native memory — integrate, migrate the SDK, inspect via CLI, and health-check a self-hosted deployment | ✓ | | |
| [`project-manager`](claude/skills/project-manager/) [(diagram)](claude/skills/project-manager/diagram.html) | AI & LLM | Feature-driven development orchestrator with bundled commands, sub-skills, and references | ✓ | ✓ | ✓ |
| [`shopify-apps`](claude/skills/shopify-apps/) | Commerce & Payments | Shopify apps — Remix, Admin API, checkout extensions | ✓ | ✓ | |
| [`woocommerce`](claude/skills/woocommerce/) | Commerce & Payments | WooCommerce REST API — products, orders, webhooks | ✓ | ✓ | |
| [`medusa`](claude/skills/medusa/) | Commerce & Payments | Medusa headless commerce — modules, workflows | ✓ | ✓ | |
| [`web-payments`](claude/skills/web-payments/) | Commerce & Payments | Stripe Checkout, subscriptions, webhooks | ✓ | ✓ | |
| [`klaviyo`](claude/skills/klaviyo/) | Third-Party Integrations | Klaviyo email/SMS — profiles, events, flows | ✓ | ✓ | |
| [`reddit-api`](claude/skills/reddit-api/) | Third-Party Integrations | Reddit API with PRAW and Snoowrap | ✓ | ✓ | |
| [`reddit-ads`](claude/skills/reddit-ads/) | Third-Party Integrations | Reddit Ads API — campaigns, targeting | ✓ | ✓ | |
| [`ms-teams-apps`](claude/skills/ms-teams-apps/) | Third-Party Integrations | Teams bots — Claude/OpenAI, Adaptive Cards | ✓ | ✓ | |
| [`posthog-analytics`](claude/skills/posthog-analytics/) | Third-Party Integrations | PostHog analytics, feature flags, dashboards | ✓ | ✓ | |
| [`site-architecture`](claude/skills/site-architecture/) | SEO & Web Presence | Technical SEO — robots.txt, sitemap, Core Web Vitals | ✓ | ✓ | |
| [`web-content`](claude/skills/web-content/) | SEO & Web Presence | SEO and AI discovery (GEO) — schema optimization | ✓ | ✓ | |
| [`aeo-optimization`](claude/skills/aeo-optimization/) | SEO & Web Presence | AI Engine Optimization — semantic triples, content clusters | ✓ | ✓ | |
| [`ac-opbta-ops`](claude/skills/ac-opbta-ops/) | Tooling & DevOps | Operator knowledge for AC_OPBTA home-network repo — Ansible, Proxmox, SOPS, OPNsense, VLANs | ✓ | | |
| [`add-remote-installer`](claude/skills/add-remote-installer/) | Tooling & DevOps | Add remote install script to a PowerShell repository | ✓ | ✓ | |
| [`content-aware-file-renaming`](claude/skills/content-aware-file-renaming/) | Tooling & DevOps | Rename file batches by content — documents, downloads, archives with structured formula | ✓ | | |
| [`graphify`](claude/skills/graphify/) | Tooling & DevOps | Turn any folder into a navigable knowledge graph — community detection, GraphRAG JSON, interactive HTML (Windows/PowerShell) | ✓ | | |
| [`project-tooling`](claude/skills/project-tooling/) | Tooling & DevOps | gh, vercel, supabase, render CLI setup | ✓ | ✓ | |
| [`workspace`](claude/skills/workspace/) | Tooling & DevOps | Multi-repo topology analysis and contract tracking | ✓ | ✓ | |
| [`publish-github`](claude/skills/publish-github/) | Tooling & DevOps | _Deprecated — folded into `github`._ Publish to GitHub with branch protection and gitleaks | ✓ | ✓ | |
| [`remote-installer`](claude/skills/remote-installer/) | Tooling & DevOps | Remote PowerShell installer domain expertise | ✓ | ✓ | |
| [`skills-manager`](claude/skills/skills-manager/) | Tooling & DevOps | Full skill lifecycle — find, sync, install, audit | ✓ | ✓ | ✓ |
| [`start-app`](claude/skills/start-app/) | Tooling & DevOps | Discover and run the correct startup command | ✓ | ✓ | |
| [`vercel-deploy-claimable`](claude/skills/vercel-deploy-claimable/) | Tooling & DevOps | Deploy to Vercel with claimable preview URLs | ✓ | ✓ | |
| [`usage-limit-reducer`](claude/skills/usage-limit-reducer/) | Tooling & DevOps | Optimize resource usage and reduce API rate limit consumption | ✓ |  |  |
| [`youtube-extraction`](claude/skills/youtube-extraction/) [(diagram)](claude/skills/youtube-extraction/diagram.html) | Research & OSINT | Reconstruct files, transcripts, and artifacts from a YouTube video — ships with `/recreate-files` | ✓ | | |
| [`youtube-prd-forensics`](claude/skills/youtube-prd-forensics/) | Research & OSINT | Create PRDs from YouTube demo videos | ✓ | ✓ | |
| [`worldview-layer-scaffold`](claude/skills/worldview-layer-scaffold/) | Research & OSINT | Scaffold WorldView GEOINT data layers | ✓ | ✓ | |
| [`video-acquisition`](claude/skills/video-acquisition/) | Research & OSINT | Download and manage video files with metadata | ✓ |  |  |
| [`worldview-shader-preset`](claude/skills/worldview-shader-preset/) | Research & OSINT | Scaffold WorldView post-processing presets | ✓ | ✓ | |
| [`transcript-acquisition`](claude/skills/transcript-acquisition/) | Research & OSINT | Fetch and process video transcripts from multiple sources | ✓ |  |  |

| [`frame-extraction`](claude/skills/frame-extraction/) | Research & OSINT | Extract frames and images from video content | ✓ |  |  |
| [`frame-content-recognition`](claude/skills/frame-content-recognition/) | Research & OSINT | Identify and classify visual content in video frames | ✓ |  |  |
| [`file-reconstruction`](claude/skills/file-reconstruction/) | Research & OSINT | Reconstruct files from extracted or partial data | ✓ |  |  |
| [`extraction-reporting`](claude/skills/extraction-reporting/) | Research & OSINT | Generate comprehensive reports from extracted content | ✓ |  |  |
| [`comment-harvesting`](claude/skills/comment-harvesting/) | Research & OSINT | Extract and process comments from video platforms | ✓ |  |  |
| [`crlf-gitattributes-normalization`](claude/skills/crlf-gitattributes-normalization/) | Code Quality | Fix CRLF/LF linter and golden-fixture false-positives via repo-level .gitattributes normalization, not reformatting | ✓ |  |  |
| [`design-critique-to-safe-refactor`](claude/skills/design-critique-to-safe-refactor/) | Code Quality | Turn design critique into safe refactors by preserving test contracts and client-side DOM hooks | ✓ |  |  |
| [`scanner-plugin-integration`](claude/skills/scanner-plugin-integration/) | Code Quality | Merge orphaned scanner scaffolds into the real package tree, keep gating in DryRun, and template new providers consistently | ✓ |  |  |
| [`security-aware-persistence-design`](claude/skills/security-aware-persistence-design/) | Code Quality | Parameterized queries, PII/DoS safeguards, real transactions, and use-gated exposure decisions for persistence features | ✓ |  |  |
| [`deploy-idempotency-two-pass-gate`](claude/skills/deploy-idempotency-two-pass-gate/) | DevOps & Tooling | Gate live infra applies by requiring a second pass to show zero changes before success | ✓ |  |  |
| [`deployment-driver-pin-rewrite-from-release-tag-source-of-truth`](claude/skills/deployment-driver-pin-rewrite-from-release-tag-source-of-truth/) | DevOps & Tooling | Edit the release-tag source of truth, not the derived image pin file, so deploy drivers re-derive correctly | ✓ |  |  |
| [`diagnostics-probe-design`](claude/skills/diagnostics-probe-design/) | DevOps & Tooling | Design read-only, multi-hypothesis diagnostic probes to root-cause infra failures before fixing | ✓ |  |  |
| [`firewall-alias-as-indirection`](claude/skills/firewall-alias-as-indirection/) | DevOps & Tooling | Firewall rules should reference named device aliases, not hardcoded IPs, so inventory churn never touches rules | ✓ |  |  |
| [`fleet-cp1252-mojibake-fix`](claude/skills/fleet-cp1252-mojibake-fix/) | DevOps & Tooling | Strip non-ASCII glyphs from script runtime output to fix cp1252/Git Bash mojibake without touching comments | ✓ |  |  |
| [`gpu-workload-placement-and-arbitration`](claude/skills/gpu-workload-placement-and-arbitration/) | DevOps & Tooling | Plan and validate GPU workload placement and VRAM arbitration when services share one card | ✓ |  |  |
| [`grafana-dashboard-workflow`](claude/skills/grafana-dashboard-workflow/) | DevOps & Tooling | Author/retrofit Grafana dashboards with live-metric probing, a 4-row baseline, and a 4-rung verify ladder | ✓ |  |  |
| [`honcho-deriver-queue-health-diagnostics`](claude/skills/honcho-deriver-queue-health-diagnostics/) | DevOps & Tooling | Diagnose stalled Honcho/background queues via direct Postgres checks, falsifiable health criteria, and pollution audits | ✓ |  |  |
| [`lvm-thin-pool-diagnostics-recovery`](claude/skills/lvm-thin-pool-diagnostics-recovery/) | DevOps & Tooling | Layered LVM thin-pool diagnosis and recovery from ENOSPC, emergency_ro, and metadata-pressure write stalls | ✓ |  |  |
| [`multi-perspective-dns-diagnostic-ladder`](claude/skills/multi-perspective-dns-diagnostic-ladder/) | DevOps & Tooling | Layered DNS/network/dependency-chain probing ladder with mandatory verify-after-apply for root-causing failures | ✓ |  |  |
| [`shell-helper-migration`](claude/skills/shell-helper-migration/) | DevOps & Tooling | Safely migrate bash scripts' log/fail/die helpers to a shared lib while preserving exit-code contracts | ✓ |  |  |
| [`shell-migration-skip-taxonomy`](claude/skills/shell-migration-skip-taxonomy/) | DevOps & Tooling | Classify shell scripts by execution context to know which must skip centralized-helper migration | ✓ |  |  |
| [`side-effect-free-helper-library`](claude/skills/side-effect-free-helper-library/) | DevOps & Tooling | Centralize shell output/logging helpers as a silent-on-source library, validation stays in consumers | ✓ |  |  |
| [`two-surface-observability-reconciliation`](claude/skills/two-surface-observability-reconciliation/) | DevOps & Tooling | Reconcile two blind observability or source-of-truth surfaces into one trustworthy verdict | ✓ |  |  |
| [`accumulated-feature-branch-workflow`](claude/skills/accumulated-feature-branch-workflow/) | Foundations & Workflow | Structure multi-PR feature branches by risk seam, ship mixed dirty state safely | ✓ |  |  |
| [`additive-merge-conflict-resolution`](claude/skills/additive-merge-conflict-resolution/) | Foundations & Workflow | Resolve additive git conflicts on append-only files by keeping both sides | ✓ |  |  |
| [`conversation-history-mining-for-domain-knowledge`](claude/skills/conversation-history-mining-for-domain-knowledge/) | Foundations & Workflow | Mine past Claude conversation transcripts to extract domain knowledge and recurring failures | ✓ |  |  |
| [`iterative-audit-gate-with-streak-reset`](claude/skills/iterative-audit-gate-with-streak-reset/) | Foundations & Workflow | Rerun audits until two consecutive clean rounds, resetting streak on any finding | ✓ |  |  |
| [`parallel-subagent-fanout`](claude/skills/parallel-subagent-fanout/) | Foundations & Workflow | Fan out subagents by domain lens on disjoint work, then cross-validate and reconcile into one verdict | ✓ |  |  |
| [`project-plan-task-reconciliation`](claude/skills/project-plan-task-reconciliation/) | Foundations & Workflow | Reconcile completed tasks against the project plan with verified status and audit gaps | ✓ |  |  |
| [`recursive-batch-handoff`](claude/skills/recursive-batch-handoff/) | Foundations & Workflow | Split large migrations into batches, each emitting a self-repeating handoff prompt | ✓ |  |  |
| [`self-paced-loop-iteration`](claude/skills/self-paced-loop-iteration/) | Foundations & Workflow | Self-paced /loop pattern: one gated, verified unit of work per iteration until backlog drains | ✓ |  |  |
| [`spec-consistency-doc-refactoring-pattern`](claude/skills/spec-consistency-doc-refactoring-pattern/) | Foundations & Workflow | Atomically fix spec-vs-reality drift and mangled markdown docs without scope creep | ✓ |  |  |
| [`stale-symbolic-ref-detection-and-repair`](claude/skills/stale-symbolic-ref-detection-and-repair/) | Foundations & Workflow | Verify cached refs (git default branch, session memory) against live state before destructive ops | ✓ |  |  |
| [`state-file-driven-multi-turn-resumption`](claude/skills/state-file-driven-multi-turn-resumption/) | Foundations & Workflow | Resume multi-session work via a durable state file, one-step turns, and copy-ready handoff prompts | ✓ |  |  |
| [`worktree-isolated-loop`](claude/skills/worktree-isolated-loop/) | Foundations & Workflow | Isolate multi-turn/batch agent work in git worktrees and drive self-resuming loops from repo state | ✓ |  |  |
| [`brand-token-extraction-and-documentation`](claude/skills/brand-token-extraction-and-documentation/) | Frontend & UI | Extract real brand colors/logos from raw site CSS and codify them as versioned, documented design tokens | ✓ |  |  |
| [`css-variables-for-multi-theme-reskin`](claude/skills/css-variables-for-multi-theme-reskin/) | Frontend & UI | Build light/dark and multi-brand reskins as pure CSS custom-property token swaps | ✓ |  |  |
| [`react-virtualization-with-jsdom-measurement`](claude/skills/react-virtualization-with-jsdom-measurement/) | Frontend & UI | Test React list virtualization under jsdom by stubbing getBoundingClientRect and asserting DOM shape | ✓ |  |  |
| [`reactive-ui-state-with-delegated-event-routing`](claude/skills/reactive-ui-state-with-delegated-event-routing/) | Frontend & UI | Delegated event routing and callback-threading patterns for re-rendered UI, plus testable JS media-preference hooks | ✓ |  |  |
| [`self-contained-html-artifact-with-inline-assets`](claude/skills/self-contained-html-artifact-with-inline-assets/) | Frontend & UI | Build zero-dependency single-file HTML deliverables with inlined assets that theme-flip correctly | ✓ |  |  |
| [`ui-redesign-with-snapshot-regeneration`](claude/skills/ui-redesign-with-snapshot-regeneration/) | Frontend & UI | Stage UI redesigns with gated phases and a two-pass vitest -u regeneration to catch real regressions | ✓ |  |  |
</details>

---

## Instructions

Agent instructions configure specialized sub-agents with specific tools, models, and behavioral directives. Each instruction is a single `.md` file with YAML frontmatter.

> All 15 instructions are currently Claude-based and live in `claude/instructions/`.

<details>
<summary><strong>Full instruction list (15)</strong></summary>

| Instruction | Model | Description |
|-------------|-------|-------------|
| [`architect`](claude/instructions/architect.md) | Opus | Software architecture specialist — system design, scalability, ADRs |
| [`backend-api-developer`](claude/instructions/backend-api-developer.md) | Sonnet | FastAPI routes, SQLModel/Pydantic, Alembic migrations, pytest |
| [`build-error-resolver`](claude/instructions/build-error-resolver.md) | Opus | Fixes TypeScript and build errors with minimal diffs |
| [`code-reviewer`](claude/instructions/code-reviewer.md) | Opus | Quality, security, and maintainability review |
| [`doc-updater`](claude/instructions/doc-updater.md) | Opus | Generates codemaps, updates READMEs and guides |
| [`docs-test-engineer`](claude/instructions/docs-test-engineer.md) | Sonnet | Documentation and test suites for Python/FastAPI and React/TypeScript |
| [`e2e-runner`](claude/instructions/e2e-runner.md) | Opus | Playwright E2E tests — journeys, quarantine, artifacts |
| [`non-blocking-loading`](claude/instructions/non-blocking-loading.md) | — | Applies skeleton UI / non-blocking loading patterns |
| [`planner`](claude/instructions/planner.md) | Opus | Implementation plans with phases, dependencies, risk assessment |
| [`refactor-cleaner`](claude/instructions/refactor-cleaner.md) | Opus | Dead code removal using knip/depcheck/ts-prune |
| [`security-reviewer`](claude/instructions/security-reviewer.md) | Opus | OWASP Top 10, secrets, SSRF, injection detection |
| [`ship-to-prod`](claude/instructions/ship-to-prod.md) | — | PR from `uat` → `main` with safety checks and rollback plan |
| [`ship-to-uat`](claude/instructions/ship-to-uat.md) | — | PR from `dev` → `uat` for User Acceptance Testing |
| [`tdd-guide`](claude/instructions/tdd-guide.md) | Opus | Enforces write-tests-first — Red/Green/Refactor, 80%+ coverage |
| [`webui-developer`](claude/instructions/webui-developer.md) | Sonnet | React/TypeScript components, Storybook, Vitest |

</details>

---

## Commands

Slash commands available globally in Claude Code. Most delegate to a specialized instruction above.

> All commands live in `claude/commands/`.
> Some skills also ship bundled command wrappers under `claude/skills/<skill>/commands/`; these are
> installed with the skill bundle rather than listed as global archive commands.

The `project-manager` skill ships bundled commands for its markdown-driven lifecycle:
`/init-project`, `/init-features`, `/add-feature`, `/analyze-features`, `/continue-tasks`,
`/update-tasks`, `/review-tasks`, `/reinit`, `/sync-tracker`, `/sync-status`, and `/analyze-parallelism`. Its
`references/` bundle includes templates plus read-only helper scripts for deterministic status,
next-task, blocked, stale, and validation reports.

<details>
<summary><strong>Full command list (27)</strong></summary>

| Command | Description |
|---------|-------------|
| [`/analyze-repo`](claude/commands/analyze-repo.md) | Analyze repo structure, conventions, and guardrails |
| [`/analyze-workspace`](claude/commands/analyze-workspace.md) | Full workspace topology and dependency analysis |
| [`/build-fix`](claude/commands/build-fix.md) | Incrementally fix TypeScript and build errors |
| [`/check-contributors`](claude/commands/check-contributors.md) | Check project contributors; optionally enable multi-person mode |
| [`/code-review`](claude/commands/code-review.md) | Security and quality review — blocks commit on CRITICAL/HIGH |
| [`/commit`](claude/commands/commit.md) | _Deprecated — use `/commit` from the `github` skill._ Stage, pull, commit, and push |
| [`/diagnose`](claude/commands/diagnose.md) | Load diagnostic context — execution flow, logs, failure points |
| [`/e2e`](claude/commands/e2e.md) | Generate and run Playwright E2E tests with artifacts |
| [`/initialize-project`](claude/commands/initialize-project.md) | Full project setup with coding guardrails (idempotent) |
| [`/new-action`](claude/commands/new-action.md) | Guided creator for OSM profile action JSON files |
| [`/plan`](claude/commands/plan.md) | Requirements → risks → step-by-step plan; waits for confirmation |
| [`/publish-github`](claude/commands/publish-github.md) | _Deprecated — use `/publish-github` from the `github` skill._ Publish to GitHub with gitleaks, branch protection |
| [`/refactor-clean`](claude/commands/refactor-clean.md) | Safely remove dead code with test verification |
| [`/start-app`](claude/commands/start-app.md) | Discover and run the correct startup command |
| [`/sync-contracts`](claude/commands/sync-contracts.md) | Incremental workspace contract update |
| [`/tdd`](claude/commands/tdd.md) | TDD workflow — tests first, implement, 80%+ coverage |
| [`/test-coverage`](claude/commands/test-coverage.md) | Run tests with coverage; generate missing tests |
| [`/update-code-index`](claude/commands/update-code-index.md) | Regenerate `CODE_INDEX.md` from source |
| [`/update-codemaps`](claude/commands/update-codemaps.md) | Regenerate architecture docs in `docs/CODEMAPS/` |
| [`/update-docs`](claude/commands/update-docs.md) | Sync docs from source-of-truth |
| [`/diff-review`](claude/commands/diff-review.md) | Visual HTML diff review with architecture comparison |
| [`/fact-check`](claude/commands/fact-check.md) | Verify document accuracy against actual code |
| [`/generate-slides`](claude/commands/generate-slides.md) | Magazine-quality slide deck as self-contained HTML |
| [`/generate-web-diagram`](claude/commands/generate-web-diagram.md) | Standalone HTML diagram opened in browser |
| [`/plan-review`](claude/commands/plan-review.md) | Visual HTML plan review with risk assessment |
| [`/project-recap`](claude/commands/project-recap.md) | Visual project recap — architecture, decisions, debt |
| [`/skills-manager`](claude/commands/skills-manager.md) | Full skill lifecycle — find, sync, install, update, import, push, search, audit |
| [`/what-next`](claude/skills/what-next/commands/what-next.md) | Decide what to work on next in the current repo |
| [`/what-next-update`](claude/skills/what-next/commands/what-next-update.md) | Force refresh of `docs/what-next.md` cache + backlog reconciliation |

</details>

---

## Skill evaluation framework

The [`what-next`](claude/skills/what-next/) skill ships with a **reusable evaluation harness**
that is the canonical template for measuring any skill's behaviour against a set of synthetic
test scenarios. Use it as a starting point when building evals for other skills.

- [`evals/README.md`](claude/skills/what-next/evals/README.md) — 7-step run guide (setup →
  spawn subagents → timing → grade → migrate → aggregate → review) and a recipe for adding a
  new eval.
- [`evals/fixtures/`](claude/skills/what-next/evals/fixtures/) — committed synthetic repos, one
  per eval. Each fixture captures a scenario, not an expected output.
- [`evals/harness/`](claude/skills/what-next/evals/harness/) — four small, parameterised
  Python scripts that do all the mechanical work.
- [`evals/benchmarks/`](claude/skills/what-next/evals/benchmarks/) — iteration-1 and
  iteration-2 benchmark summaries preserved as historical record.
- Generated workspace artefacts (transcripts, per-run grading, review HTML) land at
  `claude/skills/<skill>-workspace/iteration-N/` and are **gitignored** — only the
  benchmark summaries enter git.

Supporting diagrams for the what-next skill itself:

- [Decision flow](claude/skills/what-next/diagram.html) — master 9-step pipeline.
- [Solution architecture](claude/skills/what-next/diagrams/solution.html) — components + invariants.
- [Feature matrix](claude/skills/what-next/diagrams/features.html) — capabilities grouped by domain.
- [Development plan](claude/skills/what-next/diagrams/plan.html) — iteration history + roadmap.

---

## Conventions

### Skill frontmatter

```yaml
---
name: my-skill
description: One-line summary of what this skill does
status: active          # active | draft | deprecated
version: 1.0.0          # semver or ISO date (optional)
requires: [base]         # dependency list (optional)
installed-from: ai-agent-kit  # set on installed copies only (legacy copies may read: llm_skills)
---
```

### Instruction frontmatter

```yaml
---
name: my-agent
description: What this agent does and when to use it
tools: Read, Grep, Glob, Bash
model: opus              # opus | sonnet | haiku
---
```

### Git workflow

- **Never delete** from archive — set `status: deprecated` instead
- All changes go through feature branch → PR → `dev` → release to `main`
- Branch naming: `feat/short-description`, `fix/short-description`, etc.
- Use the `github` skill for the whole repo lifecycle: `/publish-github` to create a hardened repo, `/commit`, `/ship-to-dev` to ship changes, `/merge` a PR into dev, `/release-to-main` for production releases, `/git-cleanup` to prune stale branches
