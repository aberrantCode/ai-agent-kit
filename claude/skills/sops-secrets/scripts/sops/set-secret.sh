#!/usr/bin/env bash
# Backs /update-auth. Sets username and/or password for a service, commits,
# pushes, syncs KeePass, and auto-applies the mapped playbook if one exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

service="${1:?usage: set-secret.sh <service> [--username <u>] [--password <p>]}"
shift
new_username=""
new_password=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --username) new_username="$2"; shift 2 ;;
    --password) new_password="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$new_username" && -z "$new_password" ]]; then
  echo "nothing to set: pass --username and/or --password" >&2
  exit 1
fi

catalog="$(sops_catalog_path)"
sops_file="$(python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(data[sys.argv[2]]['sops_file'])
" "$catalog" "$service")"

if [[ -n "$new_username" ]]; then
  username_key="$(python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(data[sys.argv[2]].get('username_key') or '')
" "$catalog" "$service")"
  if [[ "$username_key" == static:* ]]; then
    echo "username for $service is fixed (${username_key#static:}) in the catalog — not stored in SOPS, nothing to set" >&2
  else
    sops_set "$sops_file" "$username_key" "$new_username"
  fi
fi

if [[ -n "$new_password" ]]; then
  password_key="$(python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(data[sys.argv[2]]['password_key'])
" "$catalog" "$service")"
  sops_set "$sops_file" "$password_key" "$new_password"
fi

branch="$(git -C "$SCRIPT_DIR/../../../../.." rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
sops_ssh "git add '$sops_file' && git commit -m 'chore: update $service credentials' && git push origin '$branch'"

# Re-sync KeePass (existing repo-level script — not part of this bundle).
sops_ssh "bash scripts/sync-secrets-to-keepass.sh"

# Auto-apply the mapped playbook, if any — see references/secret-to-playbook-map.md.
# This script does not hardcode the mapping; that table is maintained separately
# and this is left as an explicit manual follow-up step until the mapping is wired in.
echo "Updated: $service ($([[ -n "$new_username" ]] && echo username) $([[ -n "$new_password" ]] && echo password))"
echo "Check references/secret-to-playbook-map.md for a playbook to re-run against $sops_file."
