---
name: coding-style
description: Language-agnostic coding-style baseline — immutability over mutation, file/function size caps for code (not prose), error handling, input validation at trust boundaries, and a pre-completion code-quality checklist
category: Code Quality
kind: snippet
scope: global
applies-to: [claude, codex, gemini]
targets: coding-style
source: ~/.claude/rules/coding-style.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## Language mapping (read first)

The examples below are written in JS/TS. The **principles** are language-agnostic;
translate them to the repo's actual stack rather than importing the JS syntax:

- **Immutability** → Python: return new objects / use `dataclasses.replace`, frozen
  dataclasses, tuples; don't mutate inputs. Applies to any language.
- **"No console.log"** targets **stray debug output**, not a program's real stdout.
  A CLI that prints to the console (Python `print()` in `ac_console.py`, PowerShell
  `Write-Host` in a theme script) or a build tool that prints a drift report
  (`build_tokens.py`) is emitting **intended output** — that is not a violation.
- **File / function size caps are code rules.** They do **not** apply to prose
  artifacts — spec documents, design-system pages, and generated token files
  routinely and legitimately exceed 800 lines.
- **`zod` input validation** → use the stack's idiom: `pydantic`/manual guards in
  Python, schema validation appropriate to the language. Validate inputs everywhere
  they cross a trust boundary; the *library* is not mandated.

## Immutability (CRITICAL)

ALWAYS create new objects, NEVER mutate:

```javascript
// WRONG: Mutation
function updateUser(user, name) {
  user.name = name  // MUTATION!
  return user
}

// CORRECT: Immutability
function updateUser(user, name) {
  return {
    ...user,
    name
  }
}
```

## File Organization

MANY SMALL FILES > FEW LARGE FILES:
- High cohesion, low coupling
- 200-400 lines typical, 800 max
- Extract utilities from large components
- Organize by feature/domain, not by type

## Error Handling

ALWAYS handle errors comprehensively:

```typescript
try {
  const result = await riskyOperation()
  return result
} catch (error) {
  console.error('Operation failed:', error)
  throw new Error('Detailed user-friendly message')
}
```

## Input Validation

ALWAYS validate user input:

```typescript
import { z } from 'zod'

const schema = z.object({
  email: z.string().email(),
  age: z.number().int().min(0).max(150)
})

const validated = schema.parse(input)
```

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling
- [ ] No console.log statements
- [ ] No hardcoded values
- [ ] No mutation (immutable patterns used)
