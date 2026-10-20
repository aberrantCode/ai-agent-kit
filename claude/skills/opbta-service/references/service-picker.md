# service-picker.md — choosing a service when none is resolved

Reached only when target resolution finds neither an explicit arg nor a
`.opbta-service` breadcrumb (see `routing.md`). The picker's job: let the
operator choose one key from `services:` in `AC_OPBTA/inventory/services.yml`.

## Source of the choices

Always read the live catalog — never a cached list:

```bash
python3 -c "
import yaml
svcs = yaml.safe_load(open('inventory/services.yml'))['services']
for k, v in svcs.items():
    print(f\"{k}\t{v.get('type','?')}\t{v.get('host','?')}\t{v.get('fqdn','')}\")
"
```

Present slug + `type` + `host` + `fqdn` so the operator disambiguates without
opening the file. For `/opbta-list` / `/opbta-inspect` add live health if cheap;
for a pre-op picker, catalog fields are enough.

## Picker tiers (pick the first that fits the run context)

1. **`AskUserQuestion` (default — inside Claude Code).** The harness mandates
   `AskUserQuestion` for any operator choice; never print a free-text menu. One
   question, options = catalog slugs (with `type`/`host` in each option's
   description). If the catalog has more than four services, either filter by the
   caller's hint first or fire consecutive `AskUserQuestion` batches — do not
   silently truncate to four.

2. **`Out-GridView` (PowerShell, standalone terminal).** When the picker must
   render outside a Claude Code turn — e.g. a spawned Windows Terminal tab driving
   a lifecycle op non-interactively — pipe the catalog rows to
   `Out-GridView -PassThru -Title "Select OPBTA service"` and read the selection.

3. **Spectre.Console (dotnet TUI, standalone terminal).** Where a richer
   standalone TUI is already in play, a `SelectionPrompt` over the same slug list
   is equivalent. Same data source, same contract.

All three resolve to exactly one slug, which then re-enters `routing.md`'s
auto-route matrix as though it had been passed explicitly.

## Refuse rather than guess

- **Empty / unreadable catalog** → STOP; report the path and the parse error.
  Do not fabricate a list.
- **A hint that matches nothing** → STOP; show the available slugs, don't
  silently pick the nearest.
- **A hint that matches exactly one** → skip the picker, proceed with that slug
  (announce the resolution).
- **A hint that matches several** → show only the matches in the picker.
