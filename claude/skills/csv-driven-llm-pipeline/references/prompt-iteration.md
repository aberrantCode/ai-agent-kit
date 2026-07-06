# Iterative LLM Prompt Engineering

A method for taking a classification or extraction prompt from "kind of works" to "production quality" in 2-3 iterations using only the data you already have.

The premise: small models (mistral, llama3-8b, etc.) are eager but biased. They over-classify into popular categories, hallucinate when uncertain, and miss structural rules unless you spell them out. The fix is layering, not replacing.

## The three layers

### v0 — Plain taxonomy
The naive prompt: "Pick a category from this list." The model treats it as a vibes problem and the most-common category wins.

Symptom: ~50% accuracy, with errors clustering on one or two over-represented categories ("everything is AI/ML").

### v1 — Decision rules + exemplars
Add to the prompt:

- One-line definition for each category.
- 2-3 concrete example projects per category (not just words — actual recognizable names).
- A numbered list of decision rules (R1, R2, R3, ...) that resolve common ambiguities.
- An anti-bias instruction: "classify by what the project IS (its primary deliverable), not what it uses internally."

Symptom: ~80% accuracy. The systemic bias is gone but you'll see new edge-case errors — debate cases that "could be either".

### v2 — Worked examples + anti-patterns + reasoning field
Add three more things:

- **3-5 worked examples** in the prompt: "README hint: ... → JSON output: {category: X, reasoning: 'cites R3'}". This is the highest-leverage classification-prompting technique — even better than fine-tuning for narrow taxonomies.
- **Anti-pattern block**: "common wrong call → correct answer". Especially useful for the cases v1 broke. Eight lines is enough.
- **A `<field>_reasoning` field** in the output JSON. The model must justify its choice in 1 sentence, ideally citing a rule (R1..R6) or anti-pattern. Forces grounded output AND surfaces hallucinations as detectable audit signal.

Also drop temperature from 0.2 → 0.1 once you have rules — it makes re-runs nearly deterministic, which makes A/B comparison trivial.

Symptom: ~90% accuracy with hallucinations visible in reasoning text.

## A/B harness

You don't need a full eval framework. The pipeline-state CSV already gives you the harness:

1. **Save the current prompt** to a file or commit before changes.
2. **Pick 10 representative rows** spanning the problem space (some easy, some debate cases, some that v0 got wrong).
3. **Reset the state columns** for those 10 rows so they get re-processed:

   ```powershell
   $rows = Import-Csv 'data/pipeline.csv'
   $resetUrls = @('url1', 'url2', ...) | ForEach-Object { $_.ToLower() }
   foreach ($r in $rows) {
       if ($r.url.ToLower() -in $resetUrls) {
           $r.process_done = 'false'
           $r.process_done_by_model = ''
           $r.category = ''
           $r.category_reasoning = ''
       }
   }
   $rows | Export-Csv 'data/pipeline.csv' -NoTypeInformation -Encoding utf8
   ```

4. **Run with `-Limit 10` -Phase process** — the same 10 rows get re-analyzed.
5. **Tabulate the result** by field (category, reasoning quality, hallucinations).
6. **Compare to the previous outputs** — do the v1-broken ones now work? Did anything regress?
7. **Commit the prompt change + the regenerated artifacts** as one PR. Diff is the audit trail.

A 3-iteration cycle (v0, v1, v2) takes 30-60 minutes total — far cheaper than the bulk run that the better prompt enables.

## When to stop

You're done iterating when:

- Sample accuracy is high enough for your downstream use (~90% is usually fine for a curated list; >95% for production decisions).
- Remaining errors look like genuine semantic ambiguity (debatable for humans too), not systematic bias.
- The prompt is approaching ~150 lines. Diminishing returns; consider switching to a stronger model instead.

## When to switch model instead

If after v2 you're still under 80% accuracy, the prompt isn't the bottleneck — the model is. Try a stronger one (llama3, qwen2.5, gemma2) before adding more prompt scaffolding. Set `-OllamaModel` and re-run the same A/B harness.

## What `_reasoning` fields buy you

When the model hallucinates, the reasoning field exposes it:

```json
{"category": "DevTools",
 "category_reasoning": "R1: Wakatime is DevTools so this Wakatime alternative is DevTools."}
```

vs.

```json
{"category": "DevTools",
 "category_reasoning": "R1: Wakatime is DevTools so this Wakatime alternative is DevTools."}
```

— for a project that ISN'T a Wakatime alternative. The category is right, the reasoning is hallucinated. Downstream audit can grep for cross-references that don't actually exist in the README:

```powershell
foreach ($d in (Get-ChildItem -Path 'data/repos' -Directory)) {
    $a = Get-Content "$($d.FullName)/analysis.json" -Raw | ConvertFrom-Json
    if ($a.category_reasoning -match 'wakatime') {
        $r = Get-Content "$($d.FullName)/README.md" -Raw
        if ($r -notmatch 'wakatime') {
            "Possible hallucination: $($d.Name) — reasoning mentions wakatime but README does not"
        }
    }
}
```

The reasoning field is purely an audit signal. The pipeline doesn't make decisions on it. But it lets you find and patch the failures that score-only-right-for-the-wrong-reason produces.
