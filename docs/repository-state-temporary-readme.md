# Temporary README (Repository State Snapshot)

> Generated for issue #38 as a temporary, analysis-focused README surrogate.
> Repository root: `/home/runner/work/ai-agent-kit/ai-agent-kit`

## What this repository is

`ai-agent-kit` is a multi-platform skills archive for AI coding assistants. It centralizes reusable `SKILL.md` modules, agent instructions, and command wrappers across:

- Claude (`/home/runner/work/ai-agent-kit/ai-agent-kit/claude`)
- Codex (`/home/runner/work/ai-agent-kit/ai-agent-kit/codex`)
- Gemini (`/home/runner/work/ai-agent-kit/ai-agent-kit/gemini`)

## Current repository footprint

- Total files scanned: **516**
- Markdown files: **360**
- HTML diagram files: **108**
- Primary asset concentration: `claude/` (largest surface)

## Core top-level assets

- `/home/runner/work/ai-agent-kit/ai-agent-kit/README.md` — main public catalog and usage docs
- `/home/runner/work/ai-agent-kit/ai-agent-kit/manifest.json` — generated metadata inventory consumed by installer flows
- `/home/runner/work/ai-agent-kit/ai-agent-kit/install-skills.ps1` — remote installer and interactive deployment UI
- `/home/runner/work/ai-agent-kit/ai-agent-kit/scripts/generate-manifest.py` — manifest generation script
- `/home/runner/work/ai-agent-kit/ai-agent-kit/docs/rationalization.md` — consolidation and overlap analysis

## Architecture and conventions (current)

- Archive is intended as source of truth for skill artifacts.
- Key governance conventions include:
  - never delete skills from archive (deprecate instead)
  - source -> archive flow by default
  - feature branch -> PR -> `dev` workflow
  - README parity expectations between listed and real skills

## Current operational pathways

### Install/use pathways

- Recommended: remote PowerShell installer one-liner (from main README)
- Manual: copy skill/instruction directories into local assistant profile directories

### Management pathways

- Skill lifecycle commands exist for audit/find/sync/install/update/import/push/backfill
- Repo-local command wrappers live in `.claude/commands/`

### Build/lint/test posture

- No unified root test or lint pipeline is documented for this archive itself.
- A repository maintenance command exists and was validated:
  - `python /home/runner/work/ai-agent-kit/ai-agent-kit/scripts/generate-manifest.py`

## Strengths observed

- Strong archive breadth and platform-aware structure
- Clear command-oriented skill management model
- Existing manifest-based metadata approach for installer compatibility
- Rich skill inventory with categories and coverage depth

## Gaps observed

- Main README is comprehensive but heavy for first-time contributors
- Contributor/developer workflow docs are not centrally separated (operator vs maintainer guidance)
- Overlap/conflict findings in `docs/rationalization.md` are not prominently integrated into top-level guidance
- Cross-linking between related skills and migration guidance for deprecated/overlapping scopes can be improved

## Why this temporary README exists

This document is a short-lived, analysis-oriented abstraction intended to support issue #38 follow-up work. It captures the current repository state in a format optimized for comparison and planning rather than end-user onboarding.
