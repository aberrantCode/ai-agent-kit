#!/usr/bin/env python3
"""Generate manifest.json from skill/instruction frontmatter.

Run from repo root:
    python scripts/generate-manifest.py
"""

import os, re, json, sys, argparse
from datetime import date

# Category source-of-truth marker (requirements canonical-repo.md §6, D8).
# T5 backfilled `category:` frontmatter onto every Claude SKILL.md and flipped
# resolution here from the old hardcoded CATEGORIES dict to per-skill frontmatter.
# audit.ps1 keys the missing-category severity off this explicit marker
# (legacy-dict -> warn, frontmatter -> error) — it is a deliberate signal, never a
# coverage heuristic.
CATEGORY_SOURCE = 'frontmatter'

# manifest.json shape version (requirements canonical-repo.md §7 P1). Bump on any
# breaking change to the manifest's top-level shape; documented in scripts/README.md.
SCHEMA_VERSION = 1

# Original working directory, captured before the chdir below so that a relative
# --output path resolves against where the user invoked the script, not REPO_ROOT.
INVOCATION_CWD = os.getcwd()

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(REPO_ROOT)

# Curated category display order (requirements canonical-repo.md §6, D8): NOT
# alphabetical, preserved deliberately so manifest['categories'] (and anything
# rendered from it, e.g. CATALOG.md) keeps the same reading order the archive has
# always used. This is the one piece of category knowledge that stays in the
# generator after T5 — actual skill -> category resolution now comes entirely from
# each skill's own `category:` frontmatter (read_frontmatter), never from a
# hardcoded skill list. Mirrors `$script:CategoryOrder` in
# scripts/backfill-categories.ps1 verbatim; keep both in sync if this changes.
CATEGORY_ORDER = [
    'Foundations & Workflow',
    'Languages & Runtimes',
    'Frontend',
    'Mobile (Native)',
    'UI & Design',
    'Databases & Storage',
    'Code Quality',
    'Security & Credentials',
    'AI & LLM',
    'Commerce & Payments',
    'Third-Party Integrations',
    'SEO & Web Presence',
    'Tooling & DevOps',
    'Infrastructure & Ops',
    'Research & OSINT',
]

STANDARD_SKILLS = [
    'code-review', 'git-cleanup', 'project-manager',
    'release-to-main', 'ship-to-dev', 'skills-manager',
]


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


def scan_platform(platform, claude_categories=None):
    """Scan one platform's skills/instructions.

    claude_categories: None when scanning 'claude' itself (category comes from that
    skill's own `category:` frontmatter, the D8 source of truth). A dict of
    {skill_name: category} when scanning a mirror platform ('codex', 'gemini') —
    mirrors carry no `category:` frontmatter of their own (T5 only backfilled Claude
    SKILL.md files), so they inherit the source Claude skill's category by name.
    """
    result = {'skills': {}, 'instructions': {}}

    skills_dir = os.path.join(platform, 'skills')
    if os.path.isdir(skills_dir):
        for name in sorted(os.listdir(skills_dir)):
            skill_md = os.path.join(skills_dir, name, 'SKILL.md')
            if not os.path.isfile(skill_md):
                continue
            fm = read_frontmatter(skill_md)
            if claude_categories is None:
                category = fm.get('category') or 'Other'
            else:
                category = claude_categories.get(name, 'Other')
            entry = {
                'description': fm.get('description', ''),
                'category': category,
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
    claude_scan = scan_platform('claude')
    claude_categories = {
        name: entry['category'] for name, entry in claude_scan['skills'].items()
    }
    manifest = {
        'schemaVersion': SCHEMA_VERSION,
        'generated': date.today().isoformat(),
        'standard_skills': STANDARD_SKILLS,
        'categories': CATEGORY_ORDER,
        'platforms': {'claude': claude_scan},
    }
    for platform in ('codex', 'gemini'):
        manifest['platforms'][platform] = scan_platform(
            platform, claude_categories=claude_categories)
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
    # claude first: its own `category:` frontmatter is authoritative and mirrors
    # (codex, gemini) look up their category from this dict by skill name, since
    # T5 only backfilled `category:` onto Claude SKILL.md files (D8).
    claude_categories = {}
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
                has_category_field = bool(fields.get('category'))
                if platform == 'claude':
                    category = fields.get('category') or 'Other'
                    claude_categories[name] = category
                else:
                    category = claude_categories.get(name, 'Other')
                skills[name] = {
                    'path': f'{platform}/skills/{name}/SKILL.md',
                    'frontmatterStatus': status,
                    'name': fields.get('name'),
                    'nameMatchesDir': fields.get('name') == name,
                    'description': fields.get('description', ''),
                    'category': category,
                    'hasCategoryField': has_category_field,
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
