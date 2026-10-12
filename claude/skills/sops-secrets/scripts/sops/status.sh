#!/usr/bin/env bash
# Backs /sops-status. Diagnostic only — never mutates anything.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

echo "== SOPS pipeline status =="

if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SOPS_AC_DEVOPS_HOST" true 2>/dev/null; then
  echo "[PASS] SSH reach to ac-devops ($SOPS_AC_DEVOPS_HOST)"
else
  echo "[FAIL] SSH reach to ac-devops ($SOPS_AC_DEVOPS_HOST) — remaining checks unknown, not fail"
  exit 1
fi

if sops_ssh "test -f ~/.config/sops/age/keys.txt"; then
  echo "[PASS] age key present at ~/.config/sops/age/keys.txt"
else
  echo "[FAIL] age key missing — see references/age-key-hosts.md 'Backup' for recovery"
fi

if sops_ssh "command -v sops >/dev/null && sops --version"; then
  echo "[PASS] sops binary on PATH"
else
  echo "[FAIL] sops binary not found on ac-devops"
fi

if sops_ssh "command -v python3 >/dev/null && python3 -c 'import yaml' 2>/dev/null"; then
  echo "[PASS] parser shim available (python3 + PyYAML — references/parser-tooling.md)"
else
  echo "[FAIL] python3/PyYAML missing — parser shim broken"
fi

if sops_ssh "test -f scripts/sync-secrets-to-keepass.sh"; then
  echo "[PASS] KeePass sync script present"
else
  echo "[FAIL] scripts/sync-secrets-to-keepass.sh not found — KeePass mirror can't be refreshed"
fi
