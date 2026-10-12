# Why `python3` (not `yq`) is the parser shim

Every `scripts/sops/*.sh` script that needs to pull a value out of decrypted
YAML (or walk `services-auth-catalog.yml` / `secret-to-playbook-map.md`'s
sibling data) shells out to `python3 -c '...'` with `yaml.safe_load`, not to
`yq`.

## Reasoning

- **Availability.** `python3` is guaranteed present on `ac-devops` — it's the
  Ansible control node, and Ansible itself requires it. `yq` is a separate
  package (and comes in two incompatible flavors — the Go binary by
  `mikefarah` and the Python wrapper around `jq` — that parse the same
  invocation differently). Depending on it adds a provisioning step this
  skill doesn't otherwise need.
- **No new dependency to drift.** A missing/wrong-flavor `yq` fails with a
  confusing parse error, not a clean "command not found" — exactly the kind
  of silent half-working failure `SKILL.md`'s "concrete failure modes" table
  warns about for the SOPS rule itself. `python3 -c` with `import yaml` fails
  loudly and immediately if `PyYAML` isn't installed, which it always is
  alongside Ansible.
- **One shim, reused everywhere.** `_lib.sh` exposes a single
  `sops_parse_yaml_key FILE KEYPATH` function built on this python3 one-liner,
  so every script (`get-auth.sh`, `list-services.sh`, `status.sh`, …) shares
  the exact same parsing behavior instead of five scripts each gluing `yq`
  flags together slightly differently.

## The shim shape

```bash
python3 -c '
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
for key in sys.argv[2].split("."):
    data = data[key]
print(data)
' "$FILE" "$DOTTED_KEY_PATH"
```

This is deliberately small — it is a lookup, not a YAML-editing tool. Writes
still go through `sops --set` (see `sops-workflows.md`), never through a
python3 round-trip dump, so SOPS's own encryption metadata is never at risk
of being mangled by a generic YAML dumper.
