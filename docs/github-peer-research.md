# GitHub Peer Research: Skill/Agent Archive Projects

> Generated for issue #38.
> Focus: public projects with similar "skills/instructions/agent toolkit" intent.

## Projects reviewed

## 1) travisjneuman/.claude
- URL: https://github.com/travisjneuman/.claude
- Notable patterns:
  - Landing-page-first README with clear Quick Start and verification steps
  - Explicit "what is included" inventory table (skills/agents/commands)
  - Strong discoverability links to dedicated index docs (`skills`, `agents`, `commands`)
  - Strong operational guidance (diagnostics, lifecycle, multi-machine setup)

## 2) sickn33/antigravity-awesome-skills
- URL: https://github.com/sickn33/antigravity-awesome-skills
- Notable patterns:
  - Very clear install segmentation (full install vs focused plugin paths)
  - Tool-by-tool matrix for installation and first-use prompts
  - Separation of packaging concepts (plugins vs bundles vs workflows)
  - Explicit troubleshooting and decision-support documentation

## 3) affaan-m/ECC
- URL: https://github.com/affaan-m/ECC
- Notable patterns:
  - Strong guardrails around official distribution channels and install safety
  - Clear "pick one install path" anti-duplication guidance
  - Deep release/change transparency and ecosystem hardening narratives
  - Operational recovery docs (reset/uninstall/repair) included in top-level narrative

## 4) mateusz-pietras/ai-sync
- URL: https://github.com/mateusz-pietras/ai-sync
- Notable patterns:
  - Canonical-source model (`.ai/`) with explicit output mapping per platform
  - Compact docs with schema-first structure and deterministic mapping tables
  - Regeneration markers and controlled templating boundaries documented
  - Focus on sync safety (`--force` vs default conflict-safe mode)

## 5) franklesniak/copilot-repo-template
- URL: https://github.com/franklesniak/copilot-repo-template
- Notable patterns:
  - Strong contributor enablement: explicit lint/test commands by ecosystem
  - Clear file-by-file purpose documentation for maintainers
  - Quality controls made explicit (pre-commit, CI, schema checks, actionlint)
  - Strong "new repo vs existing repo" onboarding split

---

## Cross-project insights

1. **Separation of audiences is crucial**
   - High-performing repos separate docs for users/operators/contributors/maintainers.

2. **Installation decisions should be explicit and mutually exclusive where needed**
   - Good repos include "choose one path" guidance and anti-footgun warnings.

3. **Inventory is most useful when paired with navigable indexes**
   - Large repositories avoid overwhelming README tables by linking to focused indexes.

4. **Troubleshooting and recovery are first-class docs, not afterthoughts**
   - Mature repos include diagnostics, repair, uninstall, and path conflict guidance.

5. **Generated metadata contracts should be documented as stable interfaces**
   - Repos with generated manifests/schemas provide explicit format documentation.

6. **Governance and quality checks are easier to adopt when command-ready**
   - Effective repos provide copy/paste validation commands and contribution checklists.

---

## Relevance to ai-agent-kit

`ai-agent-kit` already has strong archive depth and command infrastructure. The biggest opportunity is documentation architecture: split by persona, reduce README cognitive load, and surface maintenance/recovery/quality workflows as first-class guidance.
