#!/usr/bin/env python3
"""Generate manifest.json from skill/instruction frontmatter.

Run from repo root:
    python scripts/generate-manifest.py
"""

import os, re, json, sys, argparse
from datetime import date

# Category source-of-truth marker (requirements canonical-repo.md §6, D8).
# While categories are resolved from the hardcoded CATEGORIES dict below this is
# 'legacy-dict'; the T5 backfill flips resolution to per-skill `category:`
# frontmatter and this becomes 'frontmatter'. audit.ps1 keys the missing-category
# severity off this explicit marker (legacy-dict -> warn, frontmatter -> error) —
# it is a deliberate signal, never a coverage heuristic.
CATEGORY_SOURCE = 'legacy-dict'

# Original working directory, captured before the chdir below so that a relative
# --output path resolves against where the user invoked the script, not REPO_ROOT.
INVOCATION_CWD = os.getcwd()

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(REPO_ROOT)

CATEGORIES = {
    'Foundations & Workflow': [
        'base', 'code-deduplication', 'commit-hygiene', 'existing-repo',
        'iterative-development', 'session-management', 'team-coordination',
        'tdd-workflow', 'workspace', 'subagent-driven-development',
        'finishing-a-development-branch',
        'using-git-worktrees', 'requesting-code-review', 'ship-to-dev',
        'release-to-main', 'git-cleanup', 'guide-assistant', 'feature-start',
        'fix-start', 'pre-pr', 'retro-fit-spec', 'spec-align', 'add-feature',
        'composition-patterns', 'doc-coauthoring', 'explain-code',
        'state-file-driven-multi-turn-resumption', 'recursive-batch-handoff',
        'parallel-subagent-fanout', 'self-paced-loop-iteration',
        'additive-merge-conflict-resolution', 'project-plan-task-reconciliation',
        'spec-consistency-doc-refactoring-pattern',
        'accumulated-feature-branch-workflow', 'iterative-audit-gate-with-streak-reset',
        'conversation-history-mining-for-domain-knowledge',
        'stale-symbolic-ref-detection-and-repair', 'worktree-isolated-loop',
    ],
    'Code Quality': [
        'code-review', 'codex-review', 'gemini-review', 'playwright-testing',
        'security',
        'design-critique-to-safe-refactor', 'scanner-plugin-integration',
        'security-aware-persistence-design', 'crlf-gitattributes-normalization',
    ],
    'Languages': [
        'android-java', 'android-kotlin', 'flutter', 'nodejs-backend',
        'python', 'react-best-practices', 'react-native', 'react-web',
        'typescript',
    ],
    'Frontend & UI': [
        'frontend-design', 'pwa-development',
        'ui-mobile', 'ui-testing', 'ui-web', 'web-design-guidelines',
        'chrome-extension-builder',
        'self-contained-html-artifact-with-inline-assets',
        'brand-token-extraction-and-documentation',
        'css-variables-for-multi-theme-reskin',
        'react-virtualization-with-jsdom-measurement',
        'reactive-ui-state-with-delegated-event-routing',
        'ui-redesign-with-snapshot-regeneration',
    ],
    'Databases': [
        'aws-aurora', 'aws-dynamodb', 'azure-cosmosdb', 'cloudflare-d1',
        'database-schema', 'firebase', 'supabase', 'supabase-nextjs',
        'supabase-node', 'supabase-python',
    ],
    'AI & LLM': [
        'agentic-development', 'ai-models', 'csv-driven-llm-pipeline',
        'llm-patterns', 'project-manager',
    ],
    'DevOps & Tooling': [
        'add-remote-installer', 'project-tooling', 'publish-github',
        'remote-installer', 'skills-manager', 'start-app',
        'vercel-deploy-claimable', 'visual-explainer',
        'grafana-dashboard-workflow', 'deploy-idempotency-two-pass-gate',
        'diagnostics-probe-design', 'shell-helper-migration',
        'gpu-workload-placement-and-arbitration', 'shell-migration-skip-taxonomy',
        'firewall-alias-as-indirection', 'fleet-cp1252-mojibake-fix',
        'honcho-deriver-queue-health-diagnostics',
        'two-surface-observability-reconciliation',
        'deployment-driver-pin-rewrite-from-release-tag-source-of-truth',
        'lvm-thin-pool-diagnostics-recovery',
        'multi-perspective-dns-diagnostic-ladder', 'side-effect-free-helper-library',
    ],
    'Commerce': [
        'klaviyo', 'medusa', 'reddit-ads', 'shopify-apps', 'web-payments',
        'woocommerce',
    ],
    'Content & Marketing': [
        'aeo-optimization', 'credentials', 'ms-teams-apps',
        'posthog-analytics', 'reddit-api', 'site-architecture',
        'user-journeys', 'web-content',
    ],
    'Specialized': [
        'logo-restylizer', 'worldview-layer-scaffold',
        'worldview-shader-preset', 'youtube-prd-forensics',
    ],
}

STANDARD_SKILLS = [
    'code-review', 'git-cleanup', 'project-manager',
    'release-to-main', 'ship-to-dev', 'skills-manager',
]

# Build reverse lookup
skill_to_cat = {}
for cat, skills in CATEGORIES.items():
    for s in skills:
        if s not in skill_to_cat:
            skill_to_cat[s] = cat


def read_frontmatter(path, max_bytes=10000):
    with open(path, encoding='utf-8') as f:
        content = f.read(max_bytes)

    if not content.startswith('---'):
        return {}

    end = re.search(r'(?m)^---\s*$', content[3:])
    if not end:
        return {}

    frontmatter = content[3:3 + end.start()]
    fields = {}
    lines = frontmatter.splitlines()
    i = 0

    while i < len(lines):
        line = lines[i]
        m = re.match(r'^([A-Za-z0-9_-]+):\s*(.*)$', line)
        if not m:
            i += 1
            continue

        key, value = m.group(1), m.group(2).strip()
        if value in ('>', '>-', '>+', '|', '|-', '|+'):
            style = value[0]
            block = []
            i += 1
            while i < len(lines):
                next_line = lines[i]
                if re.match(r'^[A-Za-z0-9_-]+:\s*', next_line):
                    break
                block.append(next_line.strip())
                i += 1

            if style == '>':
                fields[key] = ' '.join(part for part in block if part).strip()
            else:
                fields[key] = '\n'.join(block).strip()
            continue

        fields[key] = value.strip().strip('"\'')
        i += 1

    return fields


def frontmatter_status(path, max_bytes=10000):
    """Return (fields, status) with status in 'ok' | 'missing' | 'unterminated'.

    Single source of frontmatter truth for the whole repo: audit.ps1 consumes the
    --validate --json output built from this instead of re-parsing YAML in PowerShell.
    """
    with open(path, encoding='utf-8') as f:
        content = f.read(max_bytes)
    if not content.startswith('---'):
        return {}, 'missing'
    if not re.search(r'(?m)^---\s*$', content[3:]):
        return {}, 'unterminated'
    return read_frontmatter(path, max_bytes), 'ok'


def scan_platform(platform):
    result = {'skills': {}, 'instructions': {}}

    skills_dir = os.path.join(platform, 'skills')
    if os.path.isdir(skills_dir):
        for name in sorted(os.listdir(skills_dir)):
            skill_md = os.path.join(skills_dir, name, 'SKILL.md')
            if not os.path.isfile(skill_md):
                continue
            fm = read_frontmatter(skill_md)
            entry = {
                'description': fm.get('description', ''),
                'category': skill_to_cat.get(name, 'Other'),
            }
            if os.path.isdir(os.path.join(skills_dir, name, 'commands')):
                entry['has_commands'] = True
            if os.path.isdir(os.path.join(skills_dir, name, 'sub-skills')):
                entry['has_sub_skills'] = True
            result['skills'][name] = entry

    instr_dir = os.path.join(platform, 'instructions')
    if os.path.isdir(instr_dir):
        for fname in sorted(os.listdir(instr_dir)):
            if not fname.endswith('.md') or fname == '.gitkeep':
                continue
            fm = read_frontmatter(os.path.join(instr_dir, fname))
            entry = {'description': fm.get('description', '')}
            if fm.get('model'):
                entry['model'] = fm['model']
            result['instructions'][fname[:-3]] = entry

    return result


def build_manifest():
    manifest = {
        'generated': date.today().isoformat(),
        'standard_skills': STANDARD_SKILLS,
        'categories': list(CATEGORIES.keys()),
        'platforms': {},
    }
    for platform in ('claude', 'codex', 'gemini'):
        manifest['platforms'][platform] = scan_platform(platform)
    return manifest


def build_validation():
    """Emit parsed frontmatter + per-skill validation records for audit.ps1.

    One parser, two consumers: audit.ps1 reads this JSON rather than re-implementing
    YAML parsing. Category severity is keyed off the top-level categorySource marker.
    """
    result = {
        'categorySource': CATEGORY_SOURCE,
        'platforms': {},
    }
    for platform in ('claude', 'codex', 'gemini'):
        skills = {}
        skills_dir = os.path.join(platform, 'skills')
        if os.path.isdir(skills_dir):
            for name in sorted(os.listdir(skills_dir)):
                skill_dir = os.path.join(skills_dir, name)
                skill_md = os.path.join(skill_dir, 'SKILL.md')
                if not os.path.isfile(skill_md):
                    continue
                fields, status = frontmatter_status(skill_md)
                category = skill_to_cat.get(name, 'Other')
                skills[name] = {
                    'path': f'{platform}/skills/{name}/SKILL.md',
                    'frontmatterStatus': status,
                    'name': fields.get('name'),
                    'nameMatchesDir': fields.get('name') == name,
                    'description': fields.get('description', ''),
                    'category': category,
                    'hasCategoryField': bool(fields.get('category')),
                    'isOther': category == 'Other',
                    'installedFrom': fields.get('installed-from'),
                    'hasDiagram': os.path.isfile(os.path.join(skill_dir, 'diagram.html')),
                }
        result['platforms'][platform] = {'skills': skills}
    return result


def resolve_output(output):
    if output is None:
        return os.path.join(REPO_ROOT, 'manifest.json')
    if os.path.isabs(output):
        return output
    return os.path.abspath(os.path.join(INVOCATION_CWD, output))


def main(argv=None):
    parser = argparse.ArgumentParser(
        description='Generate manifest.json from skill/instruction frontmatter.')
    parser.add_argument(
        '--output', metavar='PATH', default=None,
        help='Write the manifest to PATH (default: repo-root manifest.json).')
    parser.add_argument(
        '--validate', action='store_true',
        help='Read-only: emit parsed frontmatter + validation records instead of '
             'writing the manifest. Pair with --json for machine output.')
    parser.add_argument(
        '--json', action='store_true',
        help='With --validate, emit the validation payload as JSON to stdout.')
    args = parser.parse_args(argv)

    if args.validate:
        validation = build_validation()
        if args.json:
            json.dump(validation, sys.stdout, indent=2)
            sys.stdout.write('\n')
        else:
            for p, data in validation['platforms'].items():
                others = [n for n, s in data['skills'].items() if s['isOther']]
                print(f'  {p}: {len(data["skills"])} skills, '
                      f'{len(others)} without category (source={validation["categorySource"]})')
        return 0

    manifest = build_manifest()
    out_path = resolve_output(args.output)
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2)

    for p in ('claude', 'codex', 'gemini'):
        s = len(manifest['platforms'][p]['skills'])
        i = len(manifest['platforms'][p]['instructions'])
        print(f'  {p}: {s} skills, {i} instructions')

    orphans = [
        n for p in manifest['platforms'].values()
        for n, s in p['skills'].items() if s.get('category') == 'Other'
    ]
    if orphans:
        print(f'  WARNING: {len(orphans)} skills in Other: {orphans}')

    print(f'  Written to {out_path}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
