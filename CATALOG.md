<!-- GENERATED FILE — DO NOT HAND-EDIT.
     Run: pwsh ./scripts/generate-catalog.ps1 -Force
     Source: manifest.json (generated: 2026-10-29, schemaVersion: 1)
-->

# Catalog

Full generated asset index for ai-agent-kit — skills, instructions, commands,
and shared assets, across all vendors. See the root `README.md` for the mission
and orientation doc; this file is the single generated source of every table and
count (G5, `docs/requirements/canonical-repo.md`).

## Claude Skills

### Foundations & Workflow

| Skill | Description | Also in |
|---|---|---|
| [`accumulated-feature-branch-workflow`](claude/skills/accumulated-feature-branch-workflow/SKILL.md) | Use when implementing multiple related enhancements, or a large feature that must be split across risk boundaries, and you need to decide branch/PR structure. Covers accumulating related work on one shared branch with... | — |
| [`add-feature`](claude/skills/add-feature/SKILL.md) | Use when the user wants to spec out, plan, or document a new feature. Triggers on /add-feature, /create-feature-spec, or when the user says things like "I want to add a feature", "spec out a feature", "create a featur... | codex |
| [`additive-merge-conflict-resolution`](claude/skills/additive-merge-conflict-resolution/SKILL.md) | Use when a rebase or merge reports conflicts on a file where both branches only appended or inserted new content (append-only logs, registries, holding-pen documents) rather than editing the same lines. Recognizes the... | — |
| [`base`](claude/skills/base/SKILL.md) | Universal coding patterns, constraints, TDD workflow, atomic todos | codex |
| [`claim-discipline`](claude/skills/claim-discipline/SKILL.md) | Use when about to state a checkable claim as fact — a file path, a line number, a count ("appears N times", "2 stale branches"), a quote ("the rule says X"), or "file Y contains / lacks Z". Verify it with a tool call ... | — |
| [`code-deduplication`](claude/skills/code-deduplication/SKILL.md) | Prevent semantic code duplication with capability index and check-before-write | codex |
| [`commit-hygiene`](claude/skills/commit-hygiene/SKILL.md) | Atomic commits, PR size limits, commit thresholds, stacked PRs | codex |
| [`existing-repo`](claude/skills/existing-repo/SKILL.md) | Analyze existing repositories, maintain structure, setup guardrails and best practices | codex |
| [`finishing-a-development-branch`](claude/skills/finishing-a-development-branch/SKILL.md) | Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for shipping to dev via PR, keeping the br... | codex |
| [`github`](claude/skills/github/SKILL.md) | Use for any git or GitHub repository operation in the terminal, even when "git" isn't said: commit and push, ship changes via a feature-branch PR, merge PRs/branches/worktrees into dev, cut a dev→main release or provi... | codex |
| [`guide-assistant`](claude/skills/guide-assistant/SKILL.md) | Personal assistant for walking the user step-by-step through any markdown file, manual, guide, runbook, or instruction document. Use this skill whenever the user says things like "walk me through", "run me through", "... | codex |
| [`iterative-audit-gate-with-streak-reset`](claude/skills/iterative-audit-gate-with-streak-reset/SKILL.md) | Use when a deliverable, backlog closure, or shipped change must be verified against a spec/gate before being considered done, and a single clean pass isn't trustworthy enough. Runs independent auditors or verification... | — |
| [`iterative-development`](claude/skills/iterative-development/SKILL.md) | Ralph Wiggum loops - self-referential TDD iteration until tests pass | codex |
| [`one-job-test`](claude/skills/one-job-test/SKILL.md) | Test an installed agent skill against one real job to decide whether to keep it, fork it, or delete it. Use this whenever the user mentions installing, evaluating, auditing, trusting, pruning, or being disappointed by... | — |
| [`parallel-subagent-fanout`](claude/skills/parallel-subagent-fanout/SKILL.md) | Use when a task splits into independent lenses or disjoint-file subtasks — multi-layer system audits, large documentation backfills (10+ specs), batch state-transition decisions, or code/security review of a feature b... | — |
| [`project-plan-task-reconciliation`](claude/skills/project-plan-task-reconciliation/SKILL.md) | Use when reconciling a completed worker task against the project plan and backlog — appending a parseable completion block, updating plan status and archives, verifying subagent claims against actual git/repo state, a... | — |
| [`requesting-code-review`](claude/skills/requesting-code-review/SKILL.md) | Use when completing tasks, implementing major features, or before merging to verify work meets requirements | codex |
| [`self-paced-loop-iteration`](claude/skills/self-paced-loop-iteration/SKILL.md) | Use when draining a multi-task backlog, feature plan, or long-running operational workload via Claude Code's /loop command without a fixed interval — each iteration completes one bounded unit of work, verifies it, com... | — |
| [`session-manager`](claude/skills/session-manager/SKILL.md) | Owns the whole Claude Code session lifecycle plus the shared transcript (JSONL) parser. Start: resume where you left off — "what was I working on", "continue my last session", "resume work in this repo", "did I finish... | — |
| [`spawn-terminal`](claude/skills/spawn-terminal/SKILL.md) | Spawn a new Windows Terminal tab (or window) that runs an arbitrary command or PowerShell script — independent of the session that launches it, and not tied to Claude Code. Use this skill whenever the user wants to "o... | — |
| [`spec-consistency-doc-refactoring-pattern`](claude/skills/spec-consistency-doc-refactoring-pattern/SKILL.md) | Use when resolving inconsistencies between design/spec documents and deployed reality, or repairing structural drift in large markdown docs (mangled backlogs, misaligned specs, redundant catalog fields) — atomic, scop... | — |
| [`stale-symbolic-ref-detection-and-repair`](claude/skills/stale-symbolic-ref-detection-and-repair/SKILL.md) | Use when a script, agent, or session is about to act on a remembered reference — a git default branch, a cached IP/credential, an "SSH is broken" note in memory — before any destructive or high-stakes operation. Verif... | — |
| [`subagent-driven-development`](claude/skills/subagent-driven-development/SKILL.md) | Use when executing implementation plans with independent tasks in the current session | codex |
| [`team-coordination`](claude/skills/team-coordination/SKILL.md) | Multi-person projects - shared state, todo claiming, handoffs | codex |

### Languages & Runtimes

| Skill | Description | Also in |
|---|---|---|
| [`marko`](claude/skills/marko/SKILL.md) | Marko is a grumpy senior code reviewer who critiques code with zero praise inflation and never suggests fixes. Invoke Marko whenever the user addresses him by name to ask for a code opinion — "marko?", "what do you th... | — |
| [`nodejs-backend`](claude/skills/nodejs-backend/SKILL.md) | Node.js backend patterns with Express/Fastify, repositories | codex |
| [`python`](claude/skills/python/SKILL.md) | Python development with ruff, mypy, pytest - TDD and type safety | codex |
| [`typescript`](claude/skills/typescript/SKILL.md) | TypeScript strict mode with eslint and jest | codex |

### Frontend

| Skill | Description | Also in |
|---|---|---|
| [`brand-token-extraction-and-documentation`](claude/skills/brand-token-extraction-and-documentation/SKILL.md) | Use when reskinning an app with a real brand's visual identity — extract the actual palette from a live site's raw CSS (not markdown), recreate logo/icon assets programmatically with documented extraction rationale, a... | — |
| [`chrome-extension-builder`](claude/skills/chrome-extension-builder/SKILL.md) | Scaffold and setup Chrome MV3 extensions using WXT framework with React, TypeScript, and shadcn-UI. Use when creating new browser extensions, setting up content scripts, background service workers, side panels, popups... | codex, gemini |
| [`composition-patterns`](claude/skills/composition-patterns/SKILL.md) |  | codex |
| [`css-variables-for-multi-theme-reskin`](claude/skills/css-variables-for-multi-theme-reskin/SKILL.md) | Use when a mockup, dashboard, or app needs light/dark modes and/or multiple brand palettes, or when asked to "reskin" or "retheme" an existing interface without touching its structure or interaction logic. | — |
| [`pwa-development`](claude/skills/pwa-development/SKILL.md) | Progressive Web Apps - service workers, caching strategies, offline, Workbox | codex |
| [`react-best-practices`](claude/skills/react-best-practices/SKILL.md) | React and Next.js performance optimization guidelines from Vercel Engineering. This skill should be used when writing, reviewing, or refactoring React/Next.js code to ensure optimal performance patterns. Triggers on t... | codex |
| [`react-virtualization-with-jsdom-measurement`](claude/skills/react-virtualization-with-jsdom-measurement/SKILL.md) | Use when implementing or testing row/item virtualization (react-window, TanStack Virtual) for large lists (1000-10k+ rows) in a React app whose test suite runs under jsdom rather than a real browser. | — |
| [`react-web`](claude/skills/react-web/SKILL.md) | React web development with hooks, React Query, Zustand | codex |
| [`reactive-ui-state-with-delegated-event-routing`](claude/skills/reactive-ui-state-with-delegated-event-routing/SKILL.md) | Use when building or reviewing a single-page/component UI that re-renders on state change and needs a clean way to wire click/interaction handlers, or when a component must react to system preferences like prefers-col... | — |
| [`self-contained-html-artifact-with-inline-assets`](claude/skills/self-contained-html-artifact-with-inline-assets/SKILL.md) | Use when building a portable HTML deliverable (dashboard mockup, presentation, static data browser, branded page) that must open directly in any browser with zero external requests — no CDNs, no relative-path assets, ... | — |
| [`ui-redesign-with-snapshot-regeneration`](claude/skills/ui-redesign-with-snapshot-regeneration/SKILL.md) | Use when performing a multi-phase UI redesign (e.g. a Next.js/React 19 reskin) that has existing snapshot tests, or any time `vitest -u`/snapshot regeneration is needed after intentional visual changes — to avoid mask... | — |

### UI & Design

| Skill | Description | Also in |
|---|---|---|
| [`ac-logo`](claude/skills/ac-logo/SKILL.md) | Full lifecycle for AC "PCB phosphor console" brand logos in any repository — finding existing logo assets and judging them against the brand checklist, generating a new on-brand badge, reskinning an off-brand logo int... | — |
| [`design-taste-frontend`](claude/skills/design-taste-frontend/SKILL.md) | Senior UI/UX Engineer. Architect digital interfaces overriding default LLM biases. Enforces metric-based rules, strict component architecture, CSS hardware acceleration, and balanced design engineering. | — |
| [`doc-coauthoring`](claude/skills/doc-coauthoring/SKILL.md) | Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users... | codex |
| [`explain-code`](claude/skills/explain-code/SKILL.md) | Explains code with visual diagrams and analogies. Use when explaining how code works, teaching about a codebase, or when the user asks "how does this work? | codex |
| [`frontend-design`](claude/skills/frontend-design/SKILL.md) | Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, land... | codex |
| [`logo-restylizer`](claude/skills/logo-restylizer/SKILL.md) | Restylize, retheme, or transform an existing logo or icon into a new visual variant. Use this skill whenever the user wants to: create a variation of an existing logo, change logo colors or style, apply a new theme or... | codex |
| [`ui-testing`](claude/skills/ui-testing/SKILL.md) | Visual testing - catch invisible buttons, broken layouts, contrast | codex |
| [`ui-web`](claude/skills/ui-web/SKILL.md) | Web UI - glassmorphism, Tailwind, dark mode, accessibility | codex |
| [`user-journeys`](claude/skills/user-journeys/SKILL.md) | User experience flows - journey mapping, UX validation, error recovery | codex |
| [`visual-explainer`](claude/skills/visual-explainer/SKILL.md) | Generate beautiful, self-contained HTML pages that visually explain systems, code changes, plans, and data. Use when the user asks for a diagram, architecture overview, diff review, plan review, project recap, compari... | codex |
| [`web-design-guidelines`](claude/skills/web-design-guidelines/SKILL.md) | Review UI code for Web Interface Guidelines compliance. Use when asked to "review my UI", "check accessibility", "audit design", "review UX", or "check my site against best practices". | codex |

### Databases & Storage

| Skill | Description | Also in |
|---|---|---|
| [`database-schema`](claude/skills/database-schema/SKILL.md) | Schema awareness - read before coding, type generation, prevent column errors | codex |

### Code Quality

| Skill | Description | Also in |
|---|---|---|
| [`code-review`](claude/skills/code-review/SKILL.md) | Mandatory code reviews via /code-review before commits and deploys | codex |
| [`codex-review`](claude/skills/codex-review/SKILL.md) | OpenAI Codex CLI code review with GPT-5.2-Codex, CI/CD integration | codex |
| [`crlf-gitattributes-normalization`](claude/skills/crlf-gitattributes-normalization/SKILL.md) | Use when a Windows/Linux-mixed repo shows spurious linter "Delete ␍" warnings, gofmt/prettier flags files as unformatted after a clean rebase, or golden-fixture tests fail on byte-exact CRLF-vs-LF comparisons — normal... | — |
| [`design-critique-to-safe-refactor`](claude/skills/design-critique-to-safe-refactor/SKILL.md) | Use when converting a design critique, redesign request, or UX audit finding into actual code changes on a tool or feature that's already working. Ensures the refactor can't silently break existing behavior by treatin... | — |
| [`gemini-review`](claude/skills/gemini-review/SKILL.md) | Google Gemini CLI code review with Gemini 2.5 Pro, 1M token context, CI/CD integration | codex |
| [`playwright-testing`](claude/skills/playwright-testing/SKILL.md) | E2E testing with Playwright - Page Objects, cross-browser, CI/CD | codex |
| [`scanner-plugin-integration`](claude/skills/scanner-plugin-integration/SKILL.md) | Use when importing, fixing, or adding a new provider/scanner plugin (e.g. OSINT lookup services, external-API integrations) into an existing Go-style package tree — merge orphaned scaffolds into the real package, pres... | — |
| [`security-aware-persistence-design`](claude/skills/security-aware-persistence-design/SKILL.md) | Use when designing or reviewing a feature that persists user-supplied data (new DB table/API, exposing a service, or writing multi-statement Create/Update/Delete flows) — apply parameterized queries, PII handling, DoS... | — |
| [`tdd-workflow`](claude/skills/tdd-workflow/SKILL.md) | Use this skill when writing new features, fixing bugs, or refactoring code. Enforces test-driven development with 80%+ coverage including unit, integration, and E2E tests. | codex, gemini |

### Security & Credentials

| Skill | Description | Also in |
|---|---|---|
| [`credentials`](claude/skills/credentials/SKILL.md) | Centralized API key management from Access.txt | codex |
| [`security`](claude/skills/security/SKILL.md) | OWASP security patterns, secrets management, and security testing, plus a comprehensive security review checklist. Use this skill when adding authentication, handling user input, working with secrets, creating API end... | codex, gemini |
| [`sops-secrets`](claude/skills/sops-secrets/SKILL.md) | Domain expertise for SOPS-encrypted secrets in this repo — reading service logins, rotating credentials, syncing the KeePass mirror, and diagnosing SOPS itself. Use whenever the user asks for an admin username/passwor... | — |

### AI & LLM

| Skill | Description | Also in |
|---|---|---|
| [`agentic-development`](claude/skills/agentic-development/SKILL.md) | Build AI agents with Pydantic AI (Python) and Claude SDK (Node.js) | codex |
| [`ai-models`](claude/skills/ai-models/SKILL.md) | Latest AI models reference - Claude, OpenAI, Gemini, Eleven Labs, Replicate | codex |
| [`csv-driven-llm-pipeline`](claude/skills/csv-driven-llm-pipeline/SKILL.md) | Build a stateful, resumable batch pipeline driven by CSV files with per-row pipeline-state columns. Use whenever the user wants to iterate over a corpus and do per-row work that may take time, hit external APIs, call ... | — |
| [`fleet-llm`](claude/skills/fleet-llm/SKILL.md) | Talk to the operator's self-hosted Open WebUI / ollama fleet from the terminal — list local models, run a prompt on the GPU box, chat with a local LLM, get embeddings, pull or remove models, or hit any fleet endpoint ... | — |
| [`honcho`](claude/skills/honcho/SKILL.md) | Work with Honcho — the open-source, AI-native memory backend for stateful agents. Use when integrating Honcho memory/social-cognition into a Python or TypeScript codebase, migrating the Honcho SDK between versions, in... | — |
| [`llm-patterns`](claude/skills/llm-patterns/SKILL.md) | AI-first application patterns, LLM testing, prompt management | codex |
| [`project-manager`](claude/skills/project-manager/SKILL.md) | Feature-driven project orchestrator whose shared state is markdown in docs/ (REQUIREMENTS.md, feature specs, plans, task files with completion sentinels). Use to bootstrap the workflow on a repo, capture feature specs... | codex, gemini |

### SEO & Web Presence

| Skill | Description | Also in |
|---|---|---|
| [`site-architecture`](claude/skills/site-architecture/SKILL.md) | Technical SEO - robots.txt, sitemap, meta tags, Core Web Vitals | codex |
| [`web-content`](claude/skills/web-content/SKILL.md) | SEO and AI discovery (GEO) - schema, ChatGPT/Perplexity optimization | codex |

### Tooling & DevOps

| Skill | Description | Also in |
|---|---|---|
| [`ac-opbta-ops`](claude/skills/ac-opbta-ops/SKILL.md) | Repository-specific operator knowledge for AC_OPBTA (Ansible, Semaphore, SOPS, Proxmox, Docker, SSH, Tailscale, OpenVPN, WireGuard, Unbound, Pi-hole, Wazuh, OPNsense, Traefik, Prometheus/Grafana/Loki, ntopng, ntfy, Up... | — |
| [`add-remote-installer`](claude/skills/add-remote-installer/SKILL.md) | Use when the user wants to add a remote install script (install.ps1) and self-update capability to the current PowerShell repository. Detects the GitHub remote, locates the primary app script, asks for the install dir... | codex |
| [`content-aware-file-renaming`](claude/skills/content-aware-file-renaming/SKILL.md) | Use when renaming files into a structured naming formula based on their contents — especially batches of downloaded documents (statements, invoices, tax forms, receipts, contracts, confirmations), generic-named files ... | — |
| [`graphify`](claude/skills/graphify/SKILL.md) | any input (code, docs, papers, images) → knowledge graph → clustered communities → HTML + JSON + audit report. Use when user asks any question about a codebase, project content, architecture, or file relationships — e... | — |
| [`guardrails-manager`](claude/skills/guardrails-manager/SKILL.md) | Lifecycle management of vendor-neutral agent guardrails — the reusable CLAUDE.md / AGENTS.md / GEMINI.md rules, snippets, and whole-file captures archived under shared/guardrails/. Use when the user invokes /archive-g... | — |
| [`project-tooling`](claude/skills/project-tooling/SKILL.md) | gh, vercel, supabase, render CLI and deployment platform setup | codex |
| [`remote-installer`](claude/skills/remote-installer/SKILL.md) | Domain expertise for implementing a remote PowerShell install script (install.ps1) and self-update check for a GitHub-hosted repository. Covers auto-elevation, GitHub Releases API version resolution, safe download-bef... | codex |
| [`skills-manager`](claude/skills/skills-manager/SKILL.md) | Full lifecycle management of LLM skills across the workstation — finding, archiving, installing, updating, and importing skills with their complete bundles (sub-skills + companion commands). Use when the user invokes ... | codex, gemini |
| [`start-app`](claude/skills/start-app/SKILL.md) | Start any type of modern application — web apps, APIs, full-stack projects, Docker-based stacks, microservices, and more. Use this skill whenever the user wants to run, launch, start, execute, or spin up an applicatio... | codex |
| [`statusline`](claude/skills/statusline/SKILL.md) | Use when the user wants to customize, fix, install, remove, inspect, or audit the Claude Code status line — the bottom-of-terminal line that can show token/context consumption, model, git branch, and cost. Triggers on... | — |
| [`workspace`](claude/skills/workspace/SKILL.md) | Multi-repo and monorepo awareness — topology analysis, API contract tracking, cross-repo context | codex |

### Infrastructure & Ops

| Skill | Description | Also in |
|---|---|---|
| [`deploy-idempotency-two-pass-gate`](claude/skills/deploy-idempotency-two-pass-gate/SKILL.md) | Use when running any live infrastructure apply (Ansible playbook, Terraform, Docker Compose stack, or similar) — before declaring a deployment successful or moving on to smoke tests, run the apply twice and require th... | — |
| [`deployment-driver-pin-rewrite-from-release-tag-source-of-truth`](claude/skills/deployment-driver-pin-rewrite-from-release-tag-source-of-truth/SKILL.md) | Use when a deployment or build system has both a human-editable "intent" field (a release tag, plan row) and a derived "pin" artifact (an image pin file, lockfile) — ensures edits always go to the source-of-truth fiel... | — |
| [`diagnostics-probe-design`](claude/skills/diagnostics-probe-design/SKILL.md) | Use when investigating a service or infrastructure failure and before proposing any fix — verify the premise, then write a read-only, multi-hypothesis probe that combines recorded metrics with live state to pinpoint t... | — |
| [`firewall-alias-as-indirection`](claude/skills/firewall-alias-as-indirection/SKILL.md) | Use when designing or editing firewall rules for a group of devices (e.g. cameras, IoT clusters) — reference a named alias instead of hardcoded IPs so device-set changes never require rule edits, and use config-tracin... | — |
| [`fleet-cp1252-mojibake-fix`](claude/skills/fleet-cp1252-mojibake-fix/SKILL.md) | Use when shell scripts (bash/PowerShell) print non-ASCII glyphs like checkmarks, X marks, or box-drawing rules that render as mojibake under Git Bash / Windows cp1252 terminals — replace runtime output with ASCII equi... | — |
| [`gpu-workload-placement-and-arbitration`](claude/skills/gpu-workload-placement-and-arbitration/SKILL.md) | Use when planning or deploying services that touch a GPU (ML inference, image/video generation, upscaling) and multiple such services must share one physical card. Covers deciding which services need direct GPU access... | — |
| [`grafana-dashboard-engineer`](claude/skills/grafana-dashboard-engineer/SKILL.md) | Production-grade Grafana dashboard engineer. Enables rapid research, design, build, deployment, and validation of observability dashboards across Prometheus, Loki, and custom datasources. Supports IaC (Ansible/PowerSh... | — |
| [`grafana-dashboard-workflow`](claude/skills/grafana-dashboard-workflow/SKILL.md) | Use when authoring, retrofitting, or verifying Grafana service-monitoring dashboards — enforces probing live metrics before writing PromQL, a standard four-row health baseline, and a four-rung verification ladder befo... | — |
| [`honcho-deriver-queue-health-diagnostics`](claude/skills/honcho-deriver-queue-health-diagnostics/SKILL.md) | Use when a Honcho memory backend (or any background derivation/processing queue) seems stuck, slow, or is reporting suspicious pending/error counts — check both the MCP-visible layer and the server-side queue table di... | — |
| [`lvm-thin-pool-diagnostics-recovery`](claude/skills/lvm-thin-pool-diagnostics-recovery/SKILL.md) | Use when a host or guest (VM/container) using LVM thin-provisioned storage shows ENOSPC, read-only remounts, or stalled writes despite the filesystem reporting free space — covers layered diagnosis and safe recovery o... | — |
| [`multi-perspective-dns-diagnostic-ladder`](claude/skills/multi-perspective-dns-diagnostic-ladder/SKILL.md) | Use when DNS resolution is failing, inconsistent, or NXDOMAIN, or when any "mysterious" networked-service failure needs root-causing — apply a layered probing ladder (multiple resolver perspectives, or dependency-chai... | — |
| [`opbta-service`](claude/skills/opbta-service/SKILL.md) | Use when deploying, updating, retiring, inspecting, managing, or listing an internal service on svc.opbta.com (OPBTA) from any repo, not only AC_OPBTA. Covers deploy a service, add a container, stand up X on svc.opbta... | — |
| [`shell-helper-migration`](claude/skills/shell-helper-migration/SKILL.md) | Use when refactoring bash scripts to delegate to a centralized helper library (e.g. output.sh) — extracting local log/ok/fail/die/section/info/warn helper definitions, replacing them with a single source line, and pre... | — |
| [`shell-migration-skip-taxonomy`](claude/skills/shell-migration-skip-taxonomy/SKILL.md) | Use when deciding whether a shell script can safely be migrated to source a centralized helper library — classifies scripts by execution context (repo checkout vs. remote payload vs. on-host) to identify the categorie... | — |
| [`side-effect-free-helper-library`](claude/skills/side-effect-free-helper-library/SKILL.md) | Use when centralizing duplicated presentation/logging helpers (log, ok, fail, section, etc.) scattered across many shell scripts in a fleet, so consumers can safely source the shared module regardless of their own val... | — |
| [`two-surface-observability-reconciliation`](claude/skills/two-surface-observability-reconciliation/SKILL.md) | Use when a system's true state can only be seen by combining two observability surfaces that can't see each other (an API/tool-level view and a backend/infra-level view), or when two metrics pipelines disagree about w... | — |

### Research & OSINT

| Skill | Description | Also in |
|---|---|---|
| [`comment-harvesting`](claude/skills/comment-harvesting/SKILL.md) | Domain expertise for harvesting comments and threads from a YouTube video using yt-dlp. Sub-skill of `youtube-extraction`. Use when the parent skill needs comments as a primary source for filenames, repo URLs, correct... | — |
| [`extraction-reporting`](claude/skills/extraction-reporting/SKILL.md) | Domain expertise for generating the final markdown report that summarises a YouTube extraction operation — files reconstructed, evidence trail, gaps, and follow-ups. Sub-skill of `youtube-extraction`. | — |
| [`file-reconstruction`](claude/skills/file-reconstruction/SKILL.md) | Domain expertise for stitching multi-frame OCR evidence into canonical source files on disk — without duplicating overlapping lines — and for placing each file at a sensible path inside the calling repo. Sub-skill of ... | — |
| [`frame-content-recognition`](claude/skills/frame-content-recognition/SKILL.md) | Domain expertise for visually inspecting extracted video frames to identify which ones show file content (IDE panes, terminal cat, slides, READMEs) and capture path, language, and visible line ranges. Sub-skill of `yo... | — |
| [`frame-extraction`](claude/skills/frame-extraction/SKILL.md) | Domain expertise for slicing a downloaded YouTube video into image frames using ffmpeg — with sampling strategies tuned to the downstream task (file reconstruction, PRD evidence, diagram capture). Sub-skill of `youtub... | — |
| [`transcript-acquisition`](claude/skills/transcript-acquisition/SKILL.md) | Domain expertise for obtaining a timestamped transcript of a YouTube video — first via YouTube's own auto-subs/CC, falling back to local Whisper transcription of the downloaded video. Sub-skill of `youtube-extraction`... | — |
| [`video-acquisition`](claude/skills/video-acquisition/SKILL.md) | Domain expertise for downloading a YouTube video locally at a resolution suitable for later frame OCR. Sub-skill of `youtube-extraction`. Use when the parent skill needs to acquire the source video file before any fra... | — |
| [`youtube-extraction`](claude/skills/youtube-extraction/SKILL.md) | Reconstruct locally the solution depicted in a YouTube video — files, configurations, commands, transcripts, and supporting artifacts. Use whenever the user wants to extract, recreate, mirror, scrape, harvest, or rebu... | — |
| [`youtube-prd-forensics`](claude/skills/youtube-prd-forensics/SKILL.md) | Create or update a detailed Product Requirements Document from a YouTube demo video using evidence-first analysis. Use when the user wants reproducible requirements tied to timestamps, transcript/description/comments,... | codex |

## Codex Skills

### Foundations & Workflow

| Skill | Description | Also in |
|---|---|---|
| [`add-feature`](codex/skills/add-feature/SKILL.md) | Use when the user wants to spec out, plan, or document a new feature. Triggers on /add-feature, /create-feature-spec, or when the user says things like "I want to add a feature", "spec out a feature", "create a featur... | claude |
| [`base`](codex/skills/base/SKILL.md) | Universal coding patterns, constraints, TDD workflow, atomic todos | claude |
| [`code-deduplication`](codex/skills/code-deduplication/SKILL.md) | Prevent semantic code duplication with capability index and check-before-write | claude |
| [`commit-hygiene`](codex/skills/commit-hygiene/SKILL.md) | Atomic commits, PR size limits, commit thresholds, stacked PRs | claude |
| [`existing-repo`](codex/skills/existing-repo/SKILL.md) | Analyze existing repositories, maintain structure, setup guardrails and best practices | claude |
| [`finishing-a-development-branch`](codex/skills/finishing-a-development-branch/SKILL.md) | Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for shipping to dev via PR, keeping the br... | claude |
| [`github`](codex/skills/github/SKILL.md) | Use for any git or GitHub repository operation in the terminal, even when "git" isn't said: commit and push, ship changes via a feature-branch PR, merge PRs/branches/worktrees into dev, cut a dev→main release or provi... | claude |
| [`guide-assistant`](codex/skills/guide-assistant/SKILL.md) | Personal assistant for walking the user step-by-step through any markdown file, manual, guide, runbook, or instruction document. Use this skill whenever the user says things like "walk me through", "run me through", "... | claude |
| [`iterative-development`](codex/skills/iterative-development/SKILL.md) | Ralph Wiggum loops - self-referential TDD iteration until tests pass | claude |
| [`requesting-code-review`](codex/skills/requesting-code-review/SKILL.md) | Use when completing tasks, implementing major features, or before merging to verify work meets requirements | claude |
| [`subagent-driven-development`](codex/skills/subagent-driven-development/SKILL.md) | Use when executing implementation plans with independent tasks in the current session | claude |
| [`team-coordination`](codex/skills/team-coordination/SKILL.md) | Multi-person projects - shared state, todo claiming, handoffs | claude |

### Languages & Runtimes

| Skill | Description | Also in |
|---|---|---|
| [`nodejs-backend`](codex/skills/nodejs-backend/SKILL.md) | Node.js backend patterns with Express/Fastify, repositories | claude |
| [`python`](codex/skills/python/SKILL.md) | Python development with ruff, mypy, pytest - TDD and type safety | claude |
| [`typescript`](codex/skills/typescript/SKILL.md) | TypeScript strict mode with eslint and jest | claude |

### Frontend

| Skill | Description | Also in |
|---|---|---|
| [`chrome-extension-builder`](codex/skills/chrome-extension-builder/SKILL.md) | Scaffold and setup Chrome MV3 extensions using WXT framework with React, TypeScript, and shadcn-UI. Use when creating new browser extensions, setting up content scripts, background service workers, side panels, popups... | claude, gemini |
| [`composition-patterns`](codex/skills/composition-patterns/SKILL.md) |  | claude |
| [`pwa-development`](codex/skills/pwa-development/SKILL.md) | Progressive Web Apps - service workers, caching strategies, offline, Workbox | claude |
| [`react-best-practices`](codex/skills/react-best-practices/SKILL.md) | React and Next.js performance optimization guidelines from Vercel Engineering. This skill should be used when writing, reviewing, or refactoring React/Next.js code to ensure optimal performance patterns. Triggers on t... | claude |
| [`react-web`](codex/skills/react-web/SKILL.md) | React web development with hooks, React Query, Zustand | claude |

### UI & Design

| Skill | Description | Also in |
|---|---|---|
| [`doc-coauthoring`](codex/skills/doc-coauthoring/SKILL.md) | Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users... | claude |
| [`explain-code`](codex/skills/explain-code/SKILL.md) | Explains code with visual diagrams and analogies. Use when explaining how code works, teaching about a codebase, or when the user asks "how does this work? | claude |
| [`frontend-design`](codex/skills/frontend-design/SKILL.md) | Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, land... | claude |
| [`logo-restylizer`](codex/skills/logo-restylizer/SKILL.md) | Restylize, retheme, or transform an existing logo or icon into a new visual variant. Use this skill whenever the user wants to: create a variation of an existing logo, change logo colors or style, apply a new theme or... | claude |
| [`ui-testing`](codex/skills/ui-testing/SKILL.md) | Visual testing - catch invisible buttons, broken layouts, contrast | claude |
| [`ui-web`](codex/skills/ui-web/SKILL.md) | Web UI - glassmorphism, Tailwind, dark mode, accessibility | claude |
| [`user-journeys`](codex/skills/user-journeys/SKILL.md) | User experience flows - journey mapping, UX validation, error recovery | claude |
| [`visual-explainer`](codex/skills/visual-explainer/SKILL.md) | Generate beautiful, self-contained HTML pages that visually explain systems, code changes, plans, and data. Use when the user asks for a diagram, architecture overview, diff review, plan review, project recap, compari... | claude |
| [`web-design-guidelines`](codex/skills/web-design-guidelines/SKILL.md) | Review UI code for Web Interface Guidelines compliance. Use when asked to "review my UI", "check accessibility", "audit design", "review UX", or "check my site against best practices". | claude |

### Databases & Storage

| Skill | Description | Also in |
|---|---|---|
| [`database-schema`](codex/skills/database-schema/SKILL.md) | Schema awareness - read before coding, type generation, prevent column errors | claude |

### Code Quality

| Skill | Description | Also in |
|---|---|---|
| [`code-review`](codex/skills/code-review/SKILL.md) | Mandatory code reviews via /code-review before commits and deploys | claude |
| [`codex-review`](codex/skills/codex-review/SKILL.md) | OpenAI Codex CLI code review with GPT-5.2-Codex, CI/CD integration | claude |
| [`gemini-review`](codex/skills/gemini-review/SKILL.md) | Google Gemini CLI code review with Gemini 2.5 Pro, 1M token context, CI/CD integration | claude |
| [`playwright-testing`](codex/skills/playwright-testing/SKILL.md) | E2E testing with Playwright - Page Objects, cross-browser, CI/CD | claude |
| [`tdd-workflow`](codex/skills/tdd-workflow/SKILL.md) | Use this skill when writing new features, fixing bugs, or refactoring code. Enforces test-driven development with 80%+ coverage including unit, integration, and E2E tests. | claude, gemini |

### Security & Credentials

| Skill | Description | Also in |
|---|---|---|
| [`credentials`](codex/skills/credentials/SKILL.md) | Centralized API key management from Access.txt | claude |
| [`security`](codex/skills/security/SKILL.md) | OWASP security patterns, secrets management, and security testing, plus a comprehensive security review checklist. Use this skill when adding authentication, handling user input, working with secrets, creating API end... | claude, gemini |

### AI & LLM

| Skill | Description | Also in |
|---|---|---|
| [`agentic-development`](codex/skills/agentic-development/SKILL.md) | Build AI agents with Pydantic AI (Python) and Claude SDK (Node.js) | claude |
| [`ai-models`](codex/skills/ai-models/SKILL.md) | Latest AI models reference - Claude, OpenAI, Gemini, Eleven Labs, Replicate | claude |
| [`llm-patterns`](codex/skills/llm-patterns/SKILL.md) | AI-first application patterns, LLM testing, prompt management | claude |
| [`project-manager`](codex/skills/project-manager/SKILL.md) | Automated project implementation orchestrator that drives feature-driven development from a single initial prompt through to completed code. Manages the full lifecycle: extracting feature specs via interview, generati... | claude, gemini |

### SEO & Web Presence

| Skill | Description | Also in |
|---|---|---|
| [`site-architecture`](codex/skills/site-architecture/SKILL.md) | Technical SEO - robots.txt, sitemap, meta tags, Core Web Vitals | claude |
| [`web-content`](codex/skills/web-content/SKILL.md) | SEO and AI discovery (GEO) - schema, ChatGPT/Perplexity optimization | claude |

### Tooling & DevOps

| Skill | Description | Also in |
|---|---|---|
| [`add-remote-installer`](codex/skills/add-remote-installer/SKILL.md) | Use when the user wants to add a remote install script (install.ps1) and self-update capability to the current PowerShell repository. Detects the GitHub remote, locates the primary app script, asks for the install dir... | claude |
| [`project-tooling`](codex/skills/project-tooling/SKILL.md) | gh, vercel, supabase, render CLI and deployment platform setup | claude |
| [`remote-installer`](codex/skills/remote-installer/SKILL.md) | Domain expertise for implementing a remote PowerShell install script (install.ps1) and self-update check for a GitHub-hosted repository. Covers auto-elevation, GitHub Releases API version resolution, safe download-bef... | claude |
| [`skills-manager`](codex/skills/skills-manager/SKILL.md) | Full lifecycle management of LLM skills across the workstation — finding, archiving, installing, updating, and importing skills with their complete bundles (sub-skills + companion commands). Use when the user invokes ... | claude, gemini |
| [`start-app`](codex/skills/start-app/SKILL.md) | Start any type of modern application — web apps, APIs, full-stack projects, Docker-based stacks, microservices, and more. Use this skill whenever the user wants to run, launch, start, execute, or spin up an applicatio... | claude |
| [`workspace`](codex/skills/workspace/SKILL.md) | Dynamic multi-repo and monorepo awareness - analyze workspace topology, track API contracts, and maintain cross-repo context | claude |

### Research & OSINT

| Skill | Description | Also in |
|---|---|---|
| [`youtube-prd-forensics`](codex/skills/youtube-prd-forensics/SKILL.md) | Create or update a detailed Product Requirements Document from a YouTube demo video using evidence-first analysis. Use when the user wants reproducible requirements tied to timestamps, transcript/description/comments,... | claude |

## Gemini Skills

### Frontend

| Skill | Description | Also in |
|---|---|---|
| [`chrome-extension-builder`](gemini/skills/chrome-extension-builder/SKILL.md) | Scaffold and setup Chrome MV3 extensions using WXT framework with React, TypeScript, and shadcn-UI. Use when creating new browser extensions, setting up content scripts, background service workers, side panels, popups... | claude, codex |

### Code Quality

| Skill | Description | Also in |
|---|---|---|
| [`tdd-workflow`](gemini/skills/tdd-workflow/SKILL.md) | Use this skill when writing new features, fixing bugs, or refactoring code. Enforces test-driven development with 80%+ coverage including unit, integration, and E2E tests. | claude, codex |

### Security & Credentials

| Skill | Description | Also in |
|---|---|---|
| [`security`](gemini/skills/security/SKILL.md) | OWASP security patterns, secrets management, and security testing, plus a comprehensive security review checklist. Use this skill when adding authentication, handling user input, working with secrets, creating API end... | claude, codex |

### AI & LLM

| Skill | Description | Also in |
|---|---|---|
| [`project-manager`](gemini/skills/project-manager/SKILL.md) | Automated project implementation orchestrator that drives feature-driven development from a single initial prompt through to completed code. Manages the full lifecycle: extracting feature specs via interview, generati... | claude, codex |

### Tooling & DevOps

| Skill | Description | Also in |
|---|---|---|
| [`skills-manager`](gemini/skills/skills-manager/SKILL.md) | Full lifecycle management of LLM skills across the workstation — finding, archiving, installing, updating, and importing skills with their complete bundles (sub-skills + companion commands). Use when the user invokes ... | claude, codex |

## Claude Instructions

| Instruction | Description | Model |
|---|---|---|
| [architect](claude/instructions/architect.md) | Software architecture specialist for system design, scalability, and technical decision-making. Use PROACTIVELY when planning new features, refactoring large systems, or making architectural decisions. | opus |
| [backend-api-developer](claude/instructions/backend-api-developer.md) | Use this agent when working on backend API development tasks in the monorepo, including implementing FastAPI routes, creating or modifying SQLModel/Pydantic models, running database migrations with Alembic, writing or... | sonnet |
| [build-error-resolver](claude/instructions/build-error-resolver.md) | Build and TypeScript error resolution specialist. Use PROACTIVELY when build fails or type errors occur. Fixes build/type errors only with minimal diffs, no architectural edits. Focuses on getting the build green quic... | sonnet |
| [code-reviewer](claude/instructions/code-reviewer.md) | Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code. MUST BE USED for all code changes. | sonnet |
| [doc-updater](claude/instructions/doc-updater.md) | Documentation and codemap specialist. Use PROACTIVELY for updating codemaps and documentation. Runs /update-codemaps and /update-docs, generates docs/CODEMAPS/*, updates READMEs and guides. | haiku |
| [docs-test-engineer](claude/instructions/docs-test-engineer.md) | Use this agent when you need to create or update documentation, write unit or integration tests, design test plans, or establish QA guidance for the monorepo. This includes writing README files, API documentation, tes... | sonnet |
| [e2e-runner](claude/instructions/e2e-runner.md) | End-to-end testing specialist using Playwright. Use PROACTIVELY for generating, maintaining, and running E2E tests. Manages test journeys, quarantines flaky tests, uploads artifacts (screenshots, videos, traces), and ... | sonnet |
| [non-blocking-loading](claude/instructions/non-blocking-loading.md) |  | — |
| [planner](claude/instructions/planner.md) | Expert planning specialist for complex features and refactoring. Use PROACTIVELY when users request feature implementation, architectural changes, or complex refactoring. Automatically activated for planning tasks. | opus |
| [refactor-cleaner](claude/instructions/refactor-cleaner.md) | Dead code cleanup and consolidation specialist. Use PROACTIVELY for removing unused code, duplicates, and refactoring. Runs analysis tools (knip, depcheck, ts-prune) to identify dead code and safely removes it. | sonnet |
| [security-reviewer](claude/instructions/security-reviewer.md) | Security vulnerability detection and remediation specialist. Use PROACTIVELY after writing code that handles user input, authentication, API endpoints, or sensitive data. Flags secrets, SSRF, injection, unsafe crypto,... | opus |
| [ship-to-prod](claude/instructions/ship-to-prod.md) |  | — |
| [ship-to-uat](claude/instructions/ship-to-uat.md) |  | — |
| [tdd-guide](claude/instructions/tdd-guide.md) | Test-Driven Development specialist enforcing write-tests-first methodology. Use PROACTIVELY when writing new features, fixing bugs, or refactoring code. Ensures 80%+ test coverage. | sonnet |
| [webui-developer](claude/instructions/webui-developer.md) | Use this agent when working on the React/TypeScript WebUI application located in apps/webui. This includes component development, Storybook stories, linting, testing, build issues, and local development environment se... | sonnet |

## Codex Instructions

| Instruction | Description | Model |
|---|---|---|
| [architect](codex/instructions/architect.md) | Software architecture specialist for system design, scalability, and technical decision-making. Use PROACTIVELY when planning new features, refactoring large systems, or making architectural decisions. | — |
| [code-reviewer](codex/instructions/code-reviewer.md) | Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code. MUST BE USED for all code changes. | — |
| [tdd-guide](codex/instructions/tdd-guide.md) | Test-Driven Development specialist enforcing write-tests-first methodology. Use PROACTIVELY when writing new features, fixing bugs, or refactoring code. Ensures 80%+ test coverage. | — |

## Gemini Instructions

| Instruction | Description | Model |
|---|---|---|
| [architect](gemini/instructions/architect.md) | Software architecture specialist for system design, scalability, and technical decision-making. Use PROACTIVELY when planning new features, refactoring large systems, or making architectural decisions. | — |
| [code-reviewer](gemini/instructions/code-reviewer.md) | Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code. MUST BE USED for all code changes. | — |
| [tdd-guide](gemini/instructions/tdd-guide.md) | Test-Driven Development specialist enforcing write-tests-first methodology. Use PROACTIVELY when writing new features, fixing bugs, or refactoring code. Ensures 80%+ test coverage. | — |

## Commands

Global slash commands under `claude/commands/`. Skill-bundled commands are
listed on their owning skill (see `has_commands` in `manifest.json`) rather
than duplicated here.

| Command | Description |
|---|---|
| [/analyze-repo](claude/commands/analyze-repo.md) | Analyze an existing repository's structure, conventions, and guardrails. |
| [/analyze-workspace](claude/commands/analyze-workspace.md) | Full dynamic analysis of workspace topology, dependencies, and contracts. |
| [/build-fix](claude/commands/build-fix.md) | Incrementally fix TypeScript and build errors: |
| [/check-contributors](claude/commands/check-contributors.md) | Checks who's working on the project and optionally converts to a multi-person project with team state management. |
| [/code-review](claude/commands/code-review.md) | Comprehensive security and quality review of uncommitted changes: |
| [/diagnose](claude/commands/diagnose.md) | You are diagnosing an issue with the AC_OSM (OpenSource Manager) PowerShell automation framework. Use the architecture, execution flow, and log locations below to efficiently identify root causes. |
| [/diff-review](claude/commands/diff-review.md) | Generate a visual HTML diff review — before/after architecture comparison with code review analysis |
| [/e2e](claude/commands/e2e.md) | Generate and run end-to-end tests with Playwright. Creates test journeys, runs tests, captures screenshots/videos/traces, and uploads artifacts. |
| [/fact-check](claude/commands/fact-check.md) | Verify the factual accuracy of a document against the actual codebase, correct inaccuracies in place |
| [/fleet-llm](claude/commands/fleet-llm.md) | Talk to the self-hosted Open WebUI / ollama fleet — list local models, run a prompt on the GPU box, chat with a local LLM, get embeddings, pull/remove models, or hit any fleet endpoint raw. Thin wrapper over the fleet... |
| [/generate-slides](claude/commands/generate-slides.md) | Generate a stunning magazine-quality slide deck as a self-contained HTML page |
| [/generate-web-diagram](claude/commands/generate-web-diagram.md) | Generate a beautiful standalone HTML diagram and open it in the browser |
| [/initialize-project](claude/commands/initialize-project.md) | Full project setup with Claude coding guardrails. Works for both new and existing projects. |
| [/new-action](claude/commands/new-action.md) | You are creating a new action JSON file for the OSM profile configurator. The file will be placed in `assets/actions/all/`. |
| [/opbta-update](claude/commands/opbta-update.md) | Alias of /update-service — update an existing OPBTA service on svc.opbta.com (bump/reconcile image, config, ports, env, or exposure). Matches the opbta-service skill's /opbta-* command family. |
| [/plan](claude/commands/plan.md) | Restate requirements, assess risks, and create step-by-step implementation plan. WAIT for user CONFIRM before touching any code. |
| [/plan-review](claude/commands/plan-review.md) | Generate a visual HTML plan review — current codebase state vs. proposed implementation plan |
| [/project-recap](claude/commands/project-recap.md) | Generate a visual HTML project recap — rebuild mental model of a project's current state, recent decisions, and cognitive debt hotspots |
| [/refactor-clean](claude/commands/refactor-clean.md) | Safely identify and remove dead code with test verification: |
| [/skills-manager](claude/commands/skills-manager.md) | Scan the Claude profile and all C:\development projects for new or changed skills, agents, and commands. Copy them into this archive under the correct toolset subfolder, update README.md, and print a change summary. |
| [/start-app](claude/commands/start-app.md) | Start the application — uses the cached start intelligence at docs/framework/start-app.md when fresh, otherwise discovers startup scripts, selects the right one, executes it, and handles failures. Pass an optional pro... |
| [/sync-contracts](claude/commands/sync-contracts.md) | Lightweight incremental update of workspace contracts without full re-analysis. |
| [/tdd](claude/commands/tdd.md) | Enforce test-driven development workflow. Scaffold interfaces, generate tests FIRST, then implement minimal code to pass. Ensure 80%+ coverage. |
| [/test-coverage](claude/commands/test-coverage.md) | Analyze test coverage and generate missing tests: |
| [/update-code-index](claude/commands/update-code-index.md) | Regenerates `CODE_INDEX.md` by scanning the codebase for all functions, classes, hooks, and components. Organizes by capability to prevent semantic duplication. |
| [/update-codemaps](claude/commands/update-codemaps.md) | Analyze the codebase structure and update architecture documentation: |
| [/update-docs](claude/commands/update-docs.md) | Sync documentation from source-of-truth: |
| [/update-service](claude/commands/update-service.md) | Update an existing OPBTA service on svc.opbta.com — bump/reconcile image, config, ports, env, or exposure. Resolves the target from the current repo's .opbta-service breadcrumb (else a service picker), plans once for ... |

## Shared Assets

Vendor-neutral assets under `shared/` (`docs/requirements/canonical-repo.md` D1).
Each class's own `README.md` documents its conventions and is not listed as an
asset here.

### Prompts

- [expert-review-and-enhancement.md](shared/prompts/expert-review-and-enhancement.md)
- [techical-author-draft.md](shared/prompts/techical-author-draft.md)
- [training-guide-and-manual.md](shared/prompts/training-guide-and-manual.md)

### Workflows

_README only — no assets yet._

### Configs

_README only — no assets yet._

### Plugins

_README only — no assets yet._

