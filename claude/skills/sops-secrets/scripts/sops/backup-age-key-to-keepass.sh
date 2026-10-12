#!/usr/bin/env bash
# Last-line backup of the age key into the KeePass root group, entry
# "sops-age-key". Idempotent — safe to re-run after every rotation.
# See references/age-key-hosts.md "Backup".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

# Pull the key straight from ac-devops into the KeePass CLI import, without
# ever landing it in a local file or printing it to stdout.
sops_ssh "cat ~/.config/sops/age/keys.txt" | \
  keepassxc-cli import-entry --title "sops-age-key" --group "/" - 2>/dev/null \
  || {
    echo "KeePass import failed — check that keepassxc-cli is on PATH and the" >&2
    echo "KeePass database is unlocked/reachable. The age key was NOT printed." >&2
    exit 1
  }

echo "sops-age-key entry refreshed in KeePass root group."
