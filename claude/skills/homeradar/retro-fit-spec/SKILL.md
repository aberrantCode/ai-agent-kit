---
name: homeradar-retro-fit-spec
description: Use when editing a HomeRadar feature spec that has no CAP-IDs in its Capabilities section
---

# HomeRadar Retro-fit Spec

When a spec's Capabilities bullets have no `[XX-CAP-NN]` prefixes, retro-fit before making other changes.

## Steps

1. **Look up the 2-letter abbreviation** in `docs/workflow/SDLC.md` → Feature Abbreviation Registry table
2. **Number the capabilities** sequentially from `01`:
   ```markdown
   - **[PT-CAP-01]** Track price changes on saved listings
   - **[PT-CAP-02]** Evaluate alert conditions on price change
   ```
3. **Update the Status** to `In Progress` if you're about to implement
4. **Commit the retro-fit alone** before any implementation commits:
   ```
   docs: retro-fit CAP-IDs to <spec-name>.md

   Refs: XX-CAP-01
   Spec: docs/features/<spec-name>.md
   ```

## Until Retro-fitted

Use the interim commit format:
```
Refs: <spec-filename>#capabilities
Spec: docs/features/<spec-name>.md
```

e.g. `Refs: price-tracking-alerts.md#capabilities`

**Do not bundle retro-fit commits with implementation commits.**
