#!/usr/bin/env bash
# Backs /rotate-service-password. Generates a strong password, then reuses
# set-secret.sh's flow (sops --set, commit, push, KeePass sync, auto-apply pointer).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

service="${1:?usage: rotate-password.sh <service>}"

new_password="$(openssl rand -hex 24)"

"$SCRIPT_DIR/set-secret.sh" "$service" --password "$new_password"

echo "New password for $service: $new_password"
