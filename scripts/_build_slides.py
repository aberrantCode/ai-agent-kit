#!/usr/bin/env python3
"""Build the self-contained command-usage-opportunities slide deck.

Inlines the AC_DESIGN "phosphor" presentation cascade (presentation-theme.css ->
shared-theme.css, @import resolved) into one <style>, then emits the slide markup
and a tiny deck module. Self-contained HTML, no external assets. Idempotent.

    python scripts/_build_slides.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets", "ac-design")
OUT = os.path.join(ROOT, "docs", "reports", "commands-usage-opportunities-slides.html")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


# Resolve the cascade: presentation-theme.css @imports shared-theme.css. Inline
# the core first, then the presentation layer with its @import line stripped.
core = read(os.path.join(ASSETS, "shared-theme.css"))
pres = read(os.path.join(ASSETS, "presentation-theme.css"))
pres = re.sub(r'@import\s+"\./shared-theme\.css";\s*', "", pres)
CSS = core + "\n\n" + pres

# Deck-local additions: a few utility classes the slides lean on that are not in
# the shared system (severity chips, usage bars, fragment-free static builds).
EXTRA = """
/* ---- deck-local helpers (additive; prefixed ac-cu-*) --------------------- */
.ac-cu-grid-2 { display:grid; grid-template-columns:1fr 1fr; gap:var(--ac-slide-gutter); }
.ac-cu-statrow { display:grid; grid-auto-flow:column; grid-auto-columns:1fr; gap:var(--ac-slide-gutter); align-items:end; }
.ac-cu-stat { display:flex; flex-direction:column; gap:0.4cqi; }
.ac-cu-stat__n { font-family:var(--ac-font-mono); font-variant-numeric:tabular-nums; font-size:8.5cqi; font-weight:600; line-height:0.95; color:var(--accent); text-shadow:0 0 0.5cqi var(--accent-glow); }
.ac-cu-stat__l { font-size:var(--ac-slide-caption); letter-spacing:0.14em; text-transform:uppercase; color:var(--muted); }
.ac-cu-sev { display:inline-flex; align-items:center; gap:0.6cqi; font-family:var(--ac-font-mono); font-variant-numeric:tabular-nums; font-size:var(--ac-slide-caption); letter-spacing:0.08em; text-transform:uppercase; }
.ac-cu-sev::before { content:""; width:1cqi; height:1cqi; border-radius:50%; background:currentColor; box-shadow:0 0 1.2cqi -0.2cqi currentColor; }
.ac-cu-sev--high { color:var(--led-down); }
.ac-cu-sev--med  { color:var(--led-warn); }
.ac-cu-sev--low  { color:var(--accent-dim); }
.ac-cu-bars { display:grid; gap:1.2cqi; }
.ac-cu-bar { display:grid; grid-template-columns:14cqi 1fr 5cqi; align-items:center; gap:1.4cqi; font-size:var(--ac-slide-caption); }
.ac-cu-bar__name { font-family:var(--ac-font-mono); color:var(--ink-soft); text-align:right; }
.ac-cu-bar__track { height:2.2cqi; background:var(--surface-1); border:1px solid var(--rule-soft); border-radius:999px; overflow:hidden; }
.ac-cu-bar__fill { height:100%; background:linear-gradient(90deg, var(--accent-dim), var(--accent)); box-shadow:0 0 1.4cqi -0.3cqi var(--accent-glow); border-radius:999px; }
.ac-cu-bar__fill--dim { background:var(--rule); box-shadow:none; }
.ac-cu-bar__n { font-family:var(--ac-font-mono); font-variant-numeric:tabular-nums; color:var(--ink); text-align:left; }
.ac-cu-pri { display:grid; gap:1.1cqi; }
.ac-cu-pri__row { display:grid; grid-template-columns:auto 1fr auto; align-items:baseline; gap:1.6cqi; padding:0.9cqi 0; border-bottom:1px solid var(--rule-soft); }
.ac-cu-pri__tag { font-family:var(--ac-font-mono); font-weight:700; color:var(--accent); font-size:var(--ac-slide-body); }
.ac-cu-pri__t { color:var(--ink); font-size:var(--ac-slide-body); line-height:1.22; }
.ac-cu-pri__t small { display:block; color:var(--muted); font-size:1.5cqi; letter-spacing:0.04em; margin-top:0.3cqi; }
.ac-cu-pri__cmd { font-family:var(--ac-font-mono); font-size:1.55cqi; color:var(--muted); white-space:nowrap; }
.ac-cu-legend { display:flex; gap:2.4cqi; }
.ac-cu-card { background:var(--surface-2); border:1px solid var(--rule); border-radius:var(--ac-radius-md); padding:1.8cqi 2cqi; display:flex; flex-direction:column; gap:0.8cqi; }
.ac-cu-card h4 { font-size:2.3cqi; font-weight:640; color:var(--ink); letter-spacing:0.01em; }
.ac-cu-card p { font-size:1.7cqi; line-height:1.34; color:var(--ink-soft); }
.ac-cu-card__k { font-size:1.4cqi; letter-spacing:0.16em; text-transform:uppercase; color:var(--accent); }
.ac-cu-fixed { border-left:0.5cqi solid var(--led-up); padding-left:2cqi; }
.ac-cu-fixed .ac-slide__title { color:var(--ink); }
.ac-deck__progress::before { box-shadow:0 0 8px -1px var(--accent-glow); }
.ac-slide__footer .ac-slide__brand-mark { font-weight:700; letter-spacing:0.12em; color:var(--accent); }
"""

# --- slide markup -----------------------------------------------------------
FOOT = ('<footer class="ac-slide__footer">'
        '<span class="ac-slide__brand-mark">AC</span>'
        '<span class="ac-slide__footer-sep">/</span>'
        '<span>AI AGENT KIT · COMMAND AUDIT</span>'
        '<span class="ac-slide__footer-sep">·</span><span>2026-10-23</span>'
        '<span class="ac-slide__page">{page}</span></footer>')

SLIDES = []

# 1 — Title
SLIDES.append(f"""
<section class="ac-slide ac-slide--title" data-active>
  <p class="ac-slide__kicker">Read-only audit · handoff cmd-opps-26a</p>
  <h1 class="ac-slide__title">Command-Usage<br>Opportunities</h1>
  <p class="ac-slide__subhead">Every slash command actually invoked across the local Claude Code corpus, mined and scanned for improvement opportunities — discovery only, nothing changed.</p>
  <p class="ac-slide__caption ac-mono">51 project dirs · 127 transcripts · orchestrated fleet · Opus synthesis</p>
  {FOOT.format(page='01')}
</section>""")

# 2 — Big numbers
SLIDES.append(f"""
<section class="ac-slide ac-slide--content">
  <p class="ac-slide__kicker">What the scan found</p>
  <div class="ac-cu-statrow">
    <div class="ac-cu-stat"><span class="ac-cu-stat__n">45</span><span class="ac-cu-stat__l">opportunities</span></div>
    <div class="ac-cu-stat"><span class="ac-cu-stat__n">16</span><span class="ac-cu-stat__l">commands used</span></div>
    <div class="ac-cu-stat"><span class="ac-cu-stat__n">89</span><span class="ac-cu-stat__l">invocations</span></div>
    <div class="ac-cu-stat"><span class="ac-cu-stat__n">10</span><span class="ac-cu-stat__l">scanned</span></div>
  </div>
  <div class="ac-rail" style="margin-top:2cqi"></div>
  <div class="ac-cu-legend" style="margin-top:1.4cqi">
    <span class="ac-cu-sev ac-cu-sev--high">11 high</span>
    <span class="ac-cu-sev ac-cu-sev--med">15 med</span>
    <span class="ac-cu-sev ac-cu-sev--low">19 low</span>
    <span class="ac-slide__caption">38 verified [V] · 7 suspected [?]</span>
  </div>
  {FOOT.format(page='02')}
</section>""")

# 3 — Pipeline (timeline)
SLIDES.append(f"""
<section class="ac-slide ac-slide--timeline">
  <div><p class="ac-slide__kicker">How it was produced</p>
  <h2 class="ac-slide__heading">An orchestrated fleet, not one loop</h2></div>
  <div class="ac-slide__track">
    <div class="ac-slide__step"><p class="ac-slide__data-label">Stage A · Haiku</p><p class="ac-slide__body">Enumerate every invocation — two signals, reconciled</p></div>
    <div class="ac-slide__step"><p class="ac-slide__data-label">Stage B · 4× Sonnet</p><p class="ac-slide__body">Per-group scan: definition + real usage episodes, parallel</p></div>
    <div class="ac-slide__step"><p class="ac-slide__data-label">Synthesis · Opus</p><p class="ac-slide__body">Group, find cross-command root causes, prioritize</p></div>
    <div class="ac-slide__step"><p class="ac-slide__data-label">Verify · Skeptic</p><p class="ac-slide__body">Adversarial pass — revised the #1 finding</p></div>
  </div>
  {FOOT.format(page='03')}
</section>""")

# 4 — Measurement caveats
SLIDES.append(f"""
<section class="ac-slide ac-slide--content">
  <p class="ac-slide__kicker">Trust the method, read the caveats</p>
  <h2 class="ac-slide__heading">The count is a floor, not the truth</h2>
  <ul class="ac-slide__list">
    <li>Counts are marker-serialized <span class="ac-mono">role=user</span> turns — natural-language skill use is invisible (<span class="ac-mono">/handoff</span> shows 0)</li>
    <li>Leading-slash signal returned 0 everywhere — the CLI expands <span class="ac-mono">/cmd</span> into the marker</li>
    <li><span class="ac-mono">repo-status</span> reconciled 30 → 10: the baseline counted the marker quoted <em>as data</em></li>
    <li>Stage-A <span class="ac-mono">improvable</span> flag is unreliable — the 10-command set comes from having a definition file</li>
  </ul>
  {FOOT.format(page='04')}
</section>""")

# 5 — Usage bars
def bar(name, n, dim=False):
    pct = round(n / 48 * 100)
    fill = "ac-cu-bar__fill ac-cu-bar__fill--dim" if dim else "ac-cu-bar__fill"
    return (f'<div class="ac-cu-bar"><span class="ac-cu-bar__name">{name}</span>'
            f'<span class="ac-cu-bar__track"><span class="{fill}" style="width:{pct}%"></span></span>'
            f'<span class="ac-cu-bar__n">{n}</span></div>')

bars = "".join([
    bar("clear", 48, dim=True),
    bar("repo-status", 10),
    bar("ship", 8),
    bar("opbta-update", 3),
    bar("start-app", 3),
    bar("update-service", 3),
    bar("continue-tasks", 2),
    bar("prune", 2),
])
SLIDES.append(f"""
<section class="ac-slide ac-slide--content">
  <p class="ac-slide__kicker">Usage distribution · top 8</p>
  <h2 class="ac-slide__heading">A few commands carry the load</h2>
  <div class="ac-cu-bars">{bars}</div>
  <p class="ac-slide__caption"><span style="color:var(--muted)">clear</span> is a non-improvable built-in (dimmed); the long tail is 1–2 invocations each.</p>
  {FOOT.format(page='05')}
</section>""")

# 6 — Section divider
SLIDES.append(f"""
<section class="ac-slide ac-slide--section">
  <p class="ac-slide__kicker">Ranked by evidence × blast radius × fix cost</p>
  <h2 class="ac-slide__section">The Shortlist</h2>
  <p class="ac-slide__subhead">Eight highest-value opportunities across all commands</p>
  {FOOT.format(page='06')}
</section>""")

# 7 — P1-P4
def pri(tag, title, sub, cmd):
    return (f'<div class="ac-cu-pri__row"><span class="ac-cu-pri__tag">{tag}</span>'
            f'<span class="ac-cu-pri__t">{title}<small>{sub}</small></span>'
            f'<span class="ac-cu-pri__cmd">{cmd}</span></div>')

p14 = "".join([
    pri("P1", "Invalid <span class='ac-mono'>gh --json autoMergeAllowed</span> field — fails every time", "Reproducible CLI error in 2 repos; silently kills auto-merge. In 3 sub-skills.", "ship · merge · repo-init"),
    pri("P2", "Installed copies drift behind — or were never pushed to — the profile", "start-app has no deployed bundle; opbta-service references/ missing at run time.", "start-app · opbta"),
    pri("P3", "No recovery when a repo's own pre-commit guard blocks the commit", "ship is the most-used workflow command; bypass improvised and undocumented.", "ship"),
    pri("P4", "Destructive-op target resolution / autonomy contract under-specified", "A mutating op resolved its target from conversation, not the 3-tier order.", "opbta-update · update-service"),
])
SLIDES.append(f"""
<section class="ac-slide ac-slide--content">
  <p class="ac-slide__kicker">Shortlist · 1–4</p>
  <div class="ac-cu-pri">{p14}</div>
  {FOOT.format(page='07')}
</section>""")

# 8 — P5-P8
p58 = "".join([
    pri("P5", "<span class='ac-mono'>continue-tasks</span> silently strands finished work on sentinel drift", "Strict enum reads 'Status: done' as malformed; work never archives. One-line fix.", "continue-tasks"),
    pri("P6", "Prerequisite check dumps a live secret into the transcript", "<span class='ac-mono'>cat .env</span> printed an API hash in cleartext — ranked by exception.", "start-app"),
    pri("P7", "Exit-0 'success' reported for a GUI app whose window never rendered", "Detached background launch has no interactive desktop; false-positive success.", "start-app"),
    pri("P8", "Approval / seed menus omit the option the real user chose", "Users answered off-menu: adversarial-review-first; interview-me-now.", "init-features · init-project"),
])
SLIDES.append(f"""
<section class="ac-slide ac-slide--content">
  <p class="ac-slide__kicker">Shortlist · 5–8</p>
  <div class="ac-cu-pri">{p58}</div>
  {FOOT.format(page='08')}
</section>""")

# 9 — Already fixed (statement/quote)
SLIDES.append(f"""
<section class="ac-slide ac-slide--quote">
  <p class="ac-slide__kicker" style="color:var(--led-up)">Verified already fixed · not actionable</p>
  <blockquote class="ac-slide__quote" style="border-left-color:var(--led-up)">The loose-skill colon-dispatch failure — a whole orchestration session running with <strong>zero</strong> workers spawned — was repaired on 2026-08-05. The ct-1 evidence predates its own fix.</blockquote>
  <p class="ac-slide__body">The skeptic caught this ranked #1; git history and the session's internal timestamps confirmed it. ship-1 took the top slot instead. The audit's rigor is in what it <em>removed</em>.</p>
  {FOOT.format(page='09')}
</section>""")

# 10 — Themes (two-col cards)
cards = "".join([
    '<div class="ac-cu-card"><span class="ac-cu-card__k">Root cause</span><h4>Deployment, not authoring</h4><p>The archive is mostly right; what ran was stale, absent, or out-of-sync. Verify the archive→profile sync.</p></div>',
    '<div class="ac-cu-card"><span class="ac-cu-card__k">Safety</span><h4>Mutating-op contract</h4><p>Routing enumerates fixed STOP conditions; real sessions hit unlisted blockers and inferred targets.</p></div>',
    '<div class="ac-cu-card"><span class="ac-cu-card__k">Reliability</span><h4>Prose vs. snippet</h4><p>Procedures narrated instead of shipped as tested snippets become per-run re-derivations — and bugs.</p></div>',
    '<div class="ac-cu-card"><span class="ac-cu-card__k">Integrity</span><h4>Reconciliation drift</h4><p>continue-tasks trusts conventions real usage broke: sentinel drift, 18 stale locks, a stale STATUS.md.</p></div>',
])
SLIDES.append(f"""
<section class="ac-slide ac-slide--content">
  <p class="ac-slide__kicker">Cross-command themes</p>
  <div class="ac-cu-grid-2">{cards}</div>
  {FOOT.format(page='10')}
</section>""")

# 11 — Roadmap (timeline)
SLIDES.append(f"""
<section class="ac-slide ac-slide--timeline">
  <div><p class="ac-slide__kicker">A later effort — not this one</p>
  <h2 class="ac-slide__heading">Where to start, by payoff per hour</h2></div>
  <div class="ac-slide__track">
    <div class="ac-slide__step"><p class="ac-slide__data-label">Now · trivial</p><p class="ac-slide__body">P1 — fix the gh field in 3 sub-skills, verify live</p></div>
    <div class="ac-slide__step"><p class="ac-slide__data-label">Next · one fix</p><p class="ac-slide__body">P2 — repair the deploy/sync + inject-body check</p></div>
    <div class="ac-slide__step"><p class="ac-slide__data-label">Then · guardrails</p><p class="ac-slide__body">P3, P5, P6 — blocked-commit, sentinel, secret-mask</p></div>
    <div class="ac-slide__step"><p class="ac-slide__data-label">Polish · UX</p><p class="ac-slide__body">P8 — add the menu options the data shows users want</p></div>
  </div>
  {FOOT.format(page='11')}
</section>""")

# 12 — Closing
SLIDES.append(f"""
<section class="ac-slide ac-slide--closing">
  <p class="ac-slide__kicker">Discovery only · no definitions changed</p>
  <h2 class="ac-slide__title" style="font-size:5.5cqi">Findings, not changes.</h2>
  <p class="ac-slide__body">Full report + evidence appendix live beside this deck:</p>
  <p class="ac-slide__caption ac-mono">docs/reports/commands-usage-opportunities.md<br>docs/reports/_stage-a-command-usage.json · _stage-b-{{github,opbta,startapp,pm}}.json</p>
  {FOOT.format(page='12')}
</section>""")

body = "\n".join(SLIDES)
N = len(SLIDES)

html = f"""<!doctype html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Command-Usage Opportunity Audit — AI Agent Kit</title>
<style>
{CSS}
{EXTRA}
</style>
</head>
<body>
<main class="ac-deck ac-deck--live" id="deck">
{body}
</main>
<div class="ac-deck__progress" id="prog"></div>
<script>
(function () {{
  var deck = document.getElementById('deck');
  var slides = Array.prototype.slice.call(deck.querySelectorAll('.ac-slide'));
  var prog = document.getElementById('prog');
  var i = 0, live = true;
  function show(n) {{
    i = Math.max(0, Math.min(slides.length - 1, n));
    slides.forEach(function (s, k) {{ if (k === i) s.setAttribute('data-active', ''); else s.removeAttribute('data-active'); }});
    prog.style.setProperty('--progress', slides.length > 1 ? i / (slides.length - 1) : 1);
    if (live) slides[i].scrollIntoView({{block: 'nearest'}});
  }}
  function setLive(on) {{
    live = on;
    deck.classList.toggle('ac-deck--live', on);
    prog.style.display = on ? '' : 'none';
    if (on) show(i);
  }}
  document.addEventListener('keydown', function (e) {{
    if (e.key === 'ArrowRight' || e.key === 'PageDown' || e.key === ' ') {{ e.preventDefault(); show(i + 1); }}
    else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {{ e.preventDefault(); show(i - 1); }}
    else if (e.key === 'Home') {{ e.preventDefault(); show(0); }}
    else if (e.key === 'End') {{ e.preventDefault(); show(slides.length - 1); }}
    else if (e.key === 'g' || e.key === 'f') {{ setLive(!live); }}
  }});
  deck.addEventListener('click', function (e) {{
    if (!live) return;
    if (e.target.closest('a')) return;
    show(i + (e.clientX < window.innerWidth * 0.32 ? -1 : 1));
  }});
  setLive(true);
}})();
</script>
</body>
</html>
"""

with open(OUT, "w", encoding="utf-8") as f:
    f.write(html)
print("wrote", OUT, "(" + str(N) + " slides,", len(html), "bytes)")
