---
name: deployment-driver-pin-rewrite-from-release-tag-source-of-truth
description: Use when a deployment or build system has both a human-editable "intent" field (a release tag, plan row) and a derived "pin" artifact (an image pin file, lockfile) — ensures edits always go to the source-of-truth field and the driver/loop re-derives the pin, rather than hand-editing the derived artifact.
status: active
version: 2026-07-05
---

# Deployment Driver: Pin Rewrite from Release-Tag Source of Truth

## When to use

- A privately-built container image (or similarly versioned artifact) has a version pin file that's generated at build time, separate from a release tag checked into the repo.
- You're designing or debugging a deployment/orchestration loop (including a `/loop`-style automation) that needs to decide "what's the next version/task to act on" without trusting stale chat history or memory.
- Someone reports a deploy "did nothing" after what looked like a version bump.

## Method

1. **Identify the true source of truth vs. the derived artifact.** For privately-built images: the release tag lives in the build script and is checked into the repo — that's authoritative. The image pin file is *derived* at build time (release tag + commit SHA baked in) — it is not something to hand-edit.

2. **Always edit the source-of-truth field, never the derived pin directly.** If you only edit the pin file by hand, the next build silently no-ops and rebuilds the *old* release — the change appears to do nothing because the driver re-derives the pin from the (unchanged) release tag on its next run.

3. **Let the driver own the derivation.** The deployment driver reads the release tag, builds the image with the commit SHA appended, and auto-rewrites the pin file (`tag:sha` format) as a build side-effect. The pin file becomes a cache of the driver's last derivation, not a place to make decisions.

4. **Apply the same source-of-truth discipline to orchestration loops.** When designing a `/loop` (or any iterative agent driver) that must decide the next action: pin the source of truth (git commit tags, plan-file task rows) and make each iteration idempotent by re-reading that source fresh every time — `git fetch` + `git log` to confirm the current `dev` tip, then re-read plan rows for the next eligible task. Do not let the loop trust chat history or a memory of "what I did last iteration" — it always re-derives from current repo state.

5. **Define explicit pause conditions** for the loop so it doesn't spin or act on stale/ambiguous state: no eligible todo task found, a release step isn't authorized yet, or the token/usage budget is approaching its limit.

## Gotchas

- Hand-editing the pin file is a *silent* no-op — there's no error, the system just quietly redeploys the old version on the next build, which makes this bug easy to miss during review.
- If two things both claim to be "the pin" (a checked-in tag and a derived file), always verify which one the driver actually reads at build time before assuming an edit will take effect.
- A loop that reasons from its own prior output instead of live repo state will drift: always re-fetch and re-read the plan/tag source per iteration rather than carrying forward an in-memory "current version."

## Diagram

[View diagram](diagram.html)
