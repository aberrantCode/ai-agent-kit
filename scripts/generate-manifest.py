#!/usr/bin/env python3
"""Generate manifest.json from skill/instruction frontmatter.

Run from repo root:
    python scripts/generate-manifest.py
"""

import os, re, json, sys
from datetime import date

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(REPO_ROOT)

CATEGORIES = {
    'Foundations & Workflow': [
        'base', 'code-deduplication', 'commit-hygiene', 'existing-repo',
        'iterative-development', 'session-management', 'team-coordination',
        'tdd-workflow', 'workspace', 'subagent-driven-development',
        'create-feature-spec', 'finishing-a-development-branch',
        'using-git-worktrees', 'requesting-code-review', 'ship-to-dev',
        'release-to-main', 'git-cleanup', 'guide-assistant', 'feature-start',
        'fix-start', 'pre-pr', 'retro-fit-spec', 'spec-align', 'add-feature',
        'composition-patterns', 'doc-coauthoring', 'explain-code',
    ],
    'Code Quality': [
        'code-review', 'codex-review', 'gemini-review', 'playwright-testing',
        'security', 'security-review',
    ],
    'Languages': [
        'android-java', 'android-kotlin', 'flutter', 'nodejs-backend',
        'python', 'react-best-practices', 'react-native', 'react-web',
        'typescript',
    ],
    'Frontend & UI': [
        'design-taste-frontend', 'frontend-design', 'pwa-development',
        'ui-mobile', 'ui-testing', 'ui-web', 'web-design-guidelines',
        'chrome-extension-builder',
    ],
    'Databases': [
        'aws-aurora', 'aws-dynamodb', 'azure-cosmosdb', 'cloudflare-d1',
        'database-schema', 'firebase', 'supabase', 'supabase-nextjs',
        'supabase-node', 'supabase-python',
    ],
    'AI & LLM': [
        'agentic-development', 'ai-models', 'llm-patterns', 'project-manager',
    ],
    'DevOps & Tooling': [
        'add-remote-installer', 'project-tooling', 'publish-github',
        'remote-installer', 'skills-manager', 'start-app',
        'vercel-deploy-claimable', 'visual-explainer',
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


def read_frontmatter(path, max_bytes=2000):
    with open(path, encoding='utf-8') as f:
        content = f.read(max_bytes)
    fields = {}
    for field in ('description', 'name', 'model'):
        m = re.search(rf'(?m)^{field}:\s*(.+)', content)
        if m:
            fields[field] = m.group(1).strip().lstrip('> ').strip()
    return fields


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


manifest = {
    'generated': date.today().isoformat(),
    'standard_skills': STANDARD_SKILLS,
    'categories': list(CATEGORIES.keys()),
    'platforms': {},
}

for platform in ('claude', 'codex', 'gemini'):
    manifest['platforms'][platform] = scan_platform(platform)

out_path = os.path.join(REPO_ROOT, 'manifest.json')
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(manifest, f, indent=2)

# Report
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
