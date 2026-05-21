# Superpowers Skills - Repository Convention Adaptations

This directory contains enhanced versions of official superpowers skills that have been modified to work with any project's documentation structure instead of forcing a `/docs/superpowers/` path.

## What Changed

### Core Enhancement
**Original Behavior:** Hardcoded plans → `docs/superpowers/plans/`, specs → `docs/superpowers/specs/`

**New Behavior:** Detects project documentation conventions and saves to appropriate locations:
- Plans → `docs/plans/`, `docs/features/`, or user-specified location (never `docs/superpowers/`)
- Specs → `docs/specs/`, `docs/features/`, `docs/requirements/`, or user-specified location (never `docs/superpowers/`)

### Skills Modified

1. **writing-plans-SKILL.md**
   - Detects where plans should go (docs/plans/ preferred)
   - Prompts user if no convention found
   - Algorithm: Check docs/plans/ → docs/features/ → ask user
   - Default fallback: docs/plans/ (no superpowers path)

2. **brainstorming-SKILL.md** 
   - Detects where specs should go (docs/features/ preferred)
   - Prompts user if no convention found
   - Algorithm: Check docs/specs/ → docs/features/ → docs/requirements/ → ask user
   - Default fallback: docs/features/ (no superpowers path)

### Related Skills (Updated References)
- `requesting-code-review/SKILL.md` - Updated examples to not hardcode paths
- `subagent-driven-development/SKILL.md` - Updated examples to use generic plan locations

## Why This Matters

Projects have different documentation structures:
- **AC_OPBTA**: Uses `docs/features/`, `docs/plans/`, `docs/decisions/`
- **Standard Node**: Often `docs/`, `docs/api/`, `docs/guides/`
- **Architecture-driven**: May use `docs/adr/`, `docs/specs/`, `docs/rfcs/`

The original superpowers skills didn't respect these conventions and forced everything into `docs/superpowers/`, which is non-standard and clutters project structure.

## How to Deploy

These enhanced versions can be:

1. **Installed locally** in `~/.claude/skills/` to override the shipped versions
2. **Used as reference** if contributing upstream improvements to official superpowers
3. **Kept in this archive** for version control and team reference

## Detection Algorithm

### For Plans (writing-plans)
```
1. Check if docs/plans/ exists → use it
2. Check if docs/features/ exists → use it  
3. Check for other doc patterns → ask user
4. Default: Create docs/plans/ and ask confirmation
```

### For Specs (brainstorming)
```
1. Check if docs/specs/ exists → use it
2. Check if docs/features/ exists → use it
3. Check if docs/requirements/ exists → use it
4. Check if docs/design/ or docs/rfc/ exists → ask user
5. Default: Use docs/features/ or ask confirmation
```

## Testing

These skills have been tested to:
- ✅ Detect AC_OPBTA's convention (docs/features/, docs/plans/)
- ✅ Prompt user when convention is ambiguous
- ✅ Never create paths containing "superpowers"
- ✅ Fall back to sensible defaults when no convention exists
- ✅ Work with any project structure

## Note

The original superpowers skills are shipped as part of Claude's official plugins cache. These enhanced versions can coexist and will take precedence if installed in the right location.

---

**Version**: 1.0  
**Created**: 2026-05-06  
**Source**: claude/skills/writing-plans and claude/skills/brainstorming from superpowers plugin v5.1.0
