#!/usr/bin/env bash
# Backs /get-service-auth. Prints URL, username, password for one service.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

service="${1:?usage: get-auth.sh <service>}"
catalog="$(sops_catalog_path)"

url="$(python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(data.get(sys.argv[2], {}).get('url') or '')
" "$catalog" "$service")"

sops_file="$(python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
entry = data.get(sys.argv[2])
if entry is None:
    sys.exit(1)
print(entry['sops_file'])
" "$catalog" "$service")"

username_key="$(python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(data[sys.argv[2]].get('username_key') or '')
" "$catalog" "$service")"

password_key="$(python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(data[sys.argv[2]]['password_key'])
" "$catalog" "$service")"

if [[ "$username_key" == static:* ]]; then
  username="${username_key#static:}"
else
  username="$(sops_parse_yaml_key "$sops_file" "$username_key")"
fi

password="$(sops_parse_yaml_key "$sops_file" "$password_key")"

echo "URL:      ${url:-<none>}"
echo "Username: ${username:-<none>}"
echo "Password: $password"
