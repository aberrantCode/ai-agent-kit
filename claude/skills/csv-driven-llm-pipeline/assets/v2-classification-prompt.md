# V2 Classification Prompt Template

A battle-tested system prompt for getting a small open model (mistral, llama3-8b, gemma2) to classify items into a fixed taxonomy at ~90% accuracy. Adapt the taxonomy and exemplars to your domain.

## Prompt structure

```
You are a [ROLE] cataloguing [DOMAIN]. Read the [INPUT TYPE] and return one strict
JSON object — no prose, no markdown fences.

OUTPUT SCHEMA (exact keys, in any order):
  short_description     : 1-2 factual sentences. No marketing words ("powerful", "cutting-edge").
  category              : one taxonomy value below, exact spelling.
  category_reasoning    : 1 sentence — why THIS category fits the [SUBJECT]'s PRIMARY purpose
                          better than the next-most-plausible category. Cite the rule (R1..Rn)
                          or anti-pattern that decided it.
  [other fields]        : ...

CATEGORIES — pick the ONE matching the [SUBJECT]'s primary [DELIVERABLE]:

  CategoryA  — [definition] (e.g. exemplar1, exemplar2, exemplar3).
  CategoryB  — [definition] (e.g. exemplar1, exemplar2, exemplar3).
  ... [one line per category, with 2-3 concrete exemplars] ...
  Other      — does not fit any above.

DECISION RULES (apply in order):
  R1. [Rule] (e.g. "Alternative to X" → match X's category).
  R2. [Rule] (e.g. UIs / dashboards → classify by the data shown).
  R3. [Rule] (e.g. SDKs / protocol implementations → match the protocol's domain).
  R4. [Rule about the most-easily-confused category].
  R5. [Rule about the most over-classified category].
  R6. [Tie-breaker rule] (e.g. on ties, prefer the more specific category).

ANTI-PATTERNS — common wrong calls and the right answer:
  "[hint phrase]" → CorrectCategory (NOT CommonWrongCategory).
  ... [8 lines, each covering a real misclassification you've seen] ...

WORKED EXAMPLES (each shows category + category_reasoning):
  Input hint: "[realistic snippet that triggers Rule N]"
    → {"category": "X", "category_reasoning": "RN: [why]."}
  ... [3-5 examples covering different rules] ...

Return JSON only.
```

## Why each piece exists

| Component | What it fixes |
|---|---|
| Schema with `category_reasoning` | Forces grounded output; surfaces hallucinations as audit signal. |
| Definitions with exemplars | Tells the model what each category contains, not just the label. |
| Decision rules with IDs | Structured fallback when categories overlap. |
| Anti-patterns block | Patches the specific misclassifications v0/v1 produce. |
| Worked examples | Most impactful single technique — shows the model the *whole* output shape, not just the field. |
| "JSON only" closer | Reduces preamble like "Here is the JSON:" that breaks parsing. |

## Inference settings

- **Temperature**: `0.1` (not 0.0 — some engines produce degenerate output at 0).
- **Top-p**: leave default.
- **Max tokens**: enough for the JSON you expect; usually 512-1024 is plenty.

## Output parsing

Models occasionally wrap JSON in markdown fences or add a preamble. Use a forgiving parser:

```powershell
$jsonPart = [regex]::Match($response, '(?s)\{.*\}')
if ($jsonPart.Success) {
    try {
        $obj = $jsonPart.Value | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse: $response"
    }
}
```

```python
import re, json
m = re.search(r'\{.*\}', response, re.S)
if m:
    try:
        obj = json.loads(m.group(0))
    except json.JSONDecodeError:
        ...
```

The regex `\{.*\}` with dot-matches-newlines + greedy is the simplest extraction that survives `prefix {valid json} suffix`.

## Reference instantiation: GitHub repo classifier

The 14-category taxonomy from the github-awesome project:

```
AI/ML, DevTools, Infrastructure, Networking, Security, Databases,
Monitoring & Observability, Web/HTTP, Containers & Virtualization,
Streaming & Events, Storage, Performance, Documentation & Learning, Other
```

Decision rules R1-R6:
1. "Alternative to X" / "self-hosted X" → match X's category.
2. UIs / dashboards → classify by data shown.
3. Protocol implementations / SDKs → match protocol's domain.
4. Security testing / red-teaming / scanners → Security, even when the target is an AI system.
5. AI/ML reserved for projects whose deliverable IS the model, runtime, or AI infrastructure.
6. On ties, prefer the more specific category (Security > DevTools, Networking > Infrastructure).

Anti-patterns:
- "Time tracking for developers" → DevTools (NOT AI/ML).
- "PDF signing" / "code signing" → Security (NOT DevTools).
- "AI model security testing" → Security (NOT AI/ML, NOT Monitoring).
- "MCP server" / "agent context protocol library" → AI/ML (NOT Web/HTTP).
- "DNS over HTTPS" / "VPN client" / "ad-blocker" → Networking (NOT Security).
- "Browser" / "browser-like UI" → Web/HTTP (NOT DevTools).
- "Awesome-list" → Documentation & Learning.
- "Static site generator" for docs → Documentation & Learning (NOT Web/HTTP).

Worked examples:
- "Self-hosted alternative to WakaTime for tracking coding time" → DevTools (R1).
- "Rust PDF signing utility supporting OpenPGP and Sigstore" → Security.
- "AI model security assessments and red-teaming" → Security (R4).
- "C++ implementation of Model Context Protocol" → AI/ML (R3).
- "DNS proxy and ad-blocker for the local network" → Networking.

This is the prompt that took the github-awesome classifier from ~50% to ~90% accuracy. Use it as a starting point — your domain-specific exemplars and anti-patterns will differ.
