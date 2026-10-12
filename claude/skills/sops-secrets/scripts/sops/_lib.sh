#!/usr/bin/env bash
# Shared library for scripts/sops/*.sh.
#
# Provides: the ac-devops SSH wrapper, the ac-devops coordination lock
# (reused from ac-opbta-ops's scripts/phases/ac-devops-lock.sh pattern), and
# the python3 parser shim (see ../../references/parser-tooling.md).
#
# Source this, don't execute it.
set -euo pipefail

SOPS_AC_DEVOPS_HOST="${SOPS_AC_DEVOPS_HOST:-ubuntu@192.168.30.15}"
SOPS_AC_DEVOPS_REPO="${SOPS_AC_DEVOPS_REPO:-~/repos/AC_OPBTA}"

# sops_ssh CMD...
# Run CMD on ac-devops, inside the repo checkout, over SSH.
# Never runs sops/python3 locally — see SKILL.md "The one rule you must never break."
sops_ssh() {
  ssh "$SOPS_AC_DEVOPS_HOST" "cd $SOPS_AC_DEVOPS_REPO && $*"
}

# sops_parse_yaml_key FILE DOTTED_KEY_PATH
# Runs on ac-devops via sops_ssh. FILE is relative to the repo root there.
# DOTTED_KEY_PATH is "." separated, e.g. "grafana.admin_password".
sops_parse_yaml_key() {
  local file="$1"
  local keypath="$2"
  sops_ssh "python3 -c '
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
for key in sys.argv[2].split(\".\"):
    data = data[key]
print(data)
' '$file' '$keypath'"
}

# sops_decrypt_extract FILE JSON_PATH
# Thin wrapper around `sops --decrypt --extract`, run on ac-devops.
sops_decrypt_extract() {
  local file="$1"
  local jsonpath="$2"
  sops_ssh "sops --decrypt --extract '$jsonpath' '$file'"
}

# sops_set FILE JSON_PATH VALUE
# Thin wrapper around `sops --set`, run on ac-devops. Atomic re-encrypt —
# never leaves a decrypted file on disk.
sops_set() {
  local file="$1"
  local jsonpath="$2"
  local value="$3"
  sops_ssh "sops --set '$jsonpath \"$value\"' '$file'"
}

# sops_catalog_path
# Path to services-auth-catalog.yml relative to this script's own directory.
sops_catalog_path() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$script_dir/../../references/services-auth-catalog.yml"
}
