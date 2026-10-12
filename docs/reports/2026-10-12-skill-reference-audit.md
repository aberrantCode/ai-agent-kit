# Skill Reference Audit — 2026-10-12

Read-only audit of every `SKILL.md` under `claude/skills/`, `codex/skills/`, and
`gemini/skills/` for intra-bundle relative-path references that point at a
file/directory that does not exist on disk. Same bug class as the
`opbta-service` fix (PR #166, now out of scope).

**Summary: 236 bundles scanned (claude 148, codex 83, gemini 5) — 13 bundles
with BROKEN references, 1 bundle UNCERTAIN, 222 clean.**

Mechanical path-extraction was fanned out to Haiku subagents; all
classification (BROKEN vs. false-positive vs. UNCERTAIN) and every existence
check quoted below was re-verified directly in the main session — two of the
six scanning subagents produced unreliable output (one mis-reported every
existence check as "no" even for files confirmed present elsewhere; one wrote
scratch files into the repo working tree, which were deleted before this
report was written — see Delegation Notes).

## BROKEN

| Skill | Vendor | SKILL.md line(s) | Referenced path | Proposed fix |
|---|---|---|---|---|
| chrome-extension-builder | claude | 530, 531 | `./assets/templates/sidepanel/`, `./assets/templates/content-script/` | Author the two starter template directories, or drop the "## Assets" section |
| chrome-extension-builder | gemini | 85, 523–525, 529, 530 | `references/wxt-config.md`, `references/mv3-permissions.md`, `references/messaging.md`, `./assets/templates/sidepanel/`, `./assets/templates/content-script/` | gemini copy ships only `SKILL.md` (no `references/`/`assets/` at all, unlike claude's copy which has `references/`) — sync the missing `references/*.md` from the claude copy and author the two template dirs |
| usage-limit-reducer | claude | 17, 20 | `scripts/usage-report.py` | Text says "the bundled script... inside this skill's directory" — author the script or drop the explicit "bundled" claim |
| workspace | claude | 818, 824 | `commands/analyze-workspace.md`, `commands/sync-contracts.md` | Author the two command files, or drop the "## Commands" rows pointing at them |
| workspace | codex | 817, 823 | `commands/analyze-workspace.md`, `commands/sync-contracts.md` | Same as claude copy |
| worldview-layer-scaffold | claude | 24, 97, 109 | `references/layer-checklist.md`, `scripts/new-layer.ps1`, `scripts/verify-layer.ps1` | Author the checklist + both scripts, or rewrite the workflow steps to not name files that don't exist |
| worldview-layer-scaffold | codex | 96, 108 | `scripts/new-layer.ps1`, `scripts/verify-layer.ps1` | codex copy already dropped the checklist-file reference (prose-only); author the two scripts or drop the "## Commands" section |
| worldview-shader-preset | claude | 24, 131, 142 | `references/shader-checklist.md`, `scripts/new-preset.ps1`, `scripts/verify-preset.ps1` | Author the checklist + both scripts, or rewrite the workflow steps |
| worldview-shader-preset | codex | 130, 141 | `scripts/new-preset.ps1`, `scripts/verify-preset.ps1` | codex copy already dropped the checklist-file reference; author the two scripts or drop the "## Commands" section |
| youtube-prd-forensics | claude | 23, 69, 77 | `references/prd-evidence-checklist.md`, `scripts/extract-keyframes-5s.ps1`, `scripts/cleanup-keyframes.ps1` | Author the checklist + both scripts, or rewrite the workflow to not claim them |
| youtube-prd-forensics | codex | 22, 68, 76 | `references/prd-evidence-checklist.md`, `scripts/extract-keyframes-5s.ps1`, `scripts/cleanup-keyframes.ps1` | Same as claude copy |
| project-manager | codex | 39, 40, 317 | `references/feature-spec-template.md`, `references/plan-template.md`, `references/task-file-template.md` | codex copy is a bare single-file port (no `references/` dir at all, unlike claude's fully-built copy) — author the three templates or sync from claude copy |
| project-manager | gemini | 39, 40, 317 | `references/feature-spec-template.md`, `references/plan-template.md`, `references/task-file-template.md` | Same as codex copy — gemini's is also a bare single-file port |

## UNCERTAIN

| Skill | Vendor | SKILL.md line(s) | Referenced path | Why uncertain |
|---|---|---|---|---|
| sops-secrets | claude | 57, 83/126, 106 | `references/age-key-hosts.md`, `references/services-auth-catalog.yml`, `references/secret-to-playbook-map.md` | Bundle ships only `SKILL.md` + `diagram.html` (no `references/`), but the SKILL.md's own "Repository layout it touches" section frames these under `.claude/skills/sops-secrets/references/` — i.e. the *installed* copy's layout, mirroring the cross-repo "index skill" pattern used by the already-confirmed-false-positive `ac-opbta-ops` (which explicitly says "it does not duplicate runbooks — it points at them"). Could not confirm from the text alone whether these should ship with the archive bundle (→ BROKEN, same bug as opbta-service) or are describing AC_OPBTA-side state (→ false positive). |
| sops-secrets | claude | 35, 63, 115, 174 | `scripts/mcp/setup-venv.sh`, `scripts/get-secret.sh`, `scripts/sync-secrets-to-keepass.sh` | Same ambiguity — the layout section separately documents a *different* path family (`scripts/sops/_lib.sh`, `get-auth.sh`, etc.) for the AC_OPBTA repo, which doesn't match these inline mentions, suggesting possible internal drift rather than a clean cross-repo/bundle split. |

(Both sops-secrets rows are the same bundle; listed as two rows to separate the `references/` vs `scripts/` path families.)

## Clean

The remaining 222 bundles (claude 141, codex 78, gemini 3) have no broken
intra-bundle relative-path references. This includes bundles with heavy
false-positive-prone content that were individually verified as correct:
`ac-opbta-ops` and `project-manager`/`session-handoff`/`statusline`/`work-resume`
(claude copies — "skill-relative" shared-parent-resource pattern, verified by
resolving sub-skill references against the parent bundle root), the `github`
sub-skills and several standalone skills (`security`, `base`, `skills-manager`,
`guardrails-manager`, `commit-hygiene`, `project-tooling`, `pwa-development`,
`agentic-development`, `code-deduplication`, `vercel-deploy-claimable`,
`spec-align`, `start-app`, `add-remote-installer`, `feature-start`) whose
`scripts/*`/`docs/*` mentions resolve to the *consuming project's* own files
(confirmed against this repo's own `scripts/` root, e.g. `validate.ps1`,
`audit.ps1`, `Generate-Changelog.ps1`) or are inside fenced illustrative code
blocks, not bundle-shipped files.

`opbta-service` was excluded from this audit per the handoff prompt (already
fixed, PR #166).

## Delegation Notes

- Of 6 Haiku scanning subagents (4 claude chunks, 1 codex, 1 gemini), one
  (claude chunk 1) wrote six scratch files into the repo working tree
  (`claude/AUDIT_RESULTS.txt`, `audit_results.txt`, `.tmp-audit/*`,
  `claude/skills/path_refs*.txt`) despite being instructed to extract only —
  all deleted before this report was committed, confirmed via `git status`.
- The codex scanning subagent's existence-check logic was broken — it
  reported "no" (missing) for literally every path it checked, including
  `diagram.html` files independently confirmed present. Its raw path list was
  used as a lead list only; every existence claim in this report was
  re-verified directly via `test -f`/`Read` in the main session, not taken
  from any subagent's output.
- Given the above, every row in this report reflects direct main-session
  verification (file reads + existence checks), not subagent-reported
  existence.
