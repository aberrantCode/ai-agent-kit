#!/usr/bin/env bash
# Backs /list-service-auth. Read-only: lists catalog structure, never decrypts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

filter="${1:-}"
catalog="$(sops_catalog_path)"

python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
flt = sys.argv[2].lower()
print(f'{\"SERVICE\":<30} {\"SOPS FILE\":<40} {\"USERNAME KEY\":<20} PASSWORD KEY')
for name, entry in sorted(data.items()):
    if flt and flt not in name.lower():
        continue
    print(f'{name:<30} {entry[\"sops_file\"]:<40} {str(entry.get(\"username_key\")):<20} {entry[\"password_key\"]}')
" "$catalog" "$filter"
