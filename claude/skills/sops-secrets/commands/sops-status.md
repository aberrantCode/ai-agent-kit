---
description: Diagnose the SOPS pipeline — SSH reach, age key, sops binary, parser tooling, KeePass mirror.
---

No arguments needed.

1. Run `scripts/sops/status.sh`. It probes, in order, on `ac-devops`:
   - SSH reach (if this step fails, every other step is reported as
     "unknown," not "fail" — can't distinguish a real failure from
     unreachable),
   - age key present at `~/.config/sops/age/keys.txt`,
   - `sops` binary on `PATH` and its version,
   - parser shim available (`python3` + `PyYAML` — see
     `references/parser-tooling.md`),
   - KeePass mirror reachable/in sync.
2. Report each step as pass/fail with the specific remediation from
   `references/sops-workflows.md`'s "Probe SOPS health" recipe (e.g. "age key
   missing" → re-provision from the KeePass backup per
   `references/age-key-hosts.md` "Backup").

This command never modifies anything — it is purely diagnostic.
