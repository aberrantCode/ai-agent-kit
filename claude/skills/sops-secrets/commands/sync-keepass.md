---
description: Re-mirror SOPS secrets into KeePass on demand.
---

No arguments. If `$ARGUMENTS` is non-empty, ignore it and proceed — this
command has nothing to parse.

1. Run `scripts/sync-secrets-to-keepass.sh` on `ac-devops` (this is the
   existing repo-level sync script this skill wraps, not a script this
   bundle ships — see `SKILL.md` "Repository layout it touches").
2. Report what changed in the KeePass mirror (entries added/updated), or
   that it was already in sync.

Useful after a manual `sops` edit made directly on `ac-devops` outside of
`/update-auth` / `/rotate-service-password` (which already sync KeePass as
part of their own flow).
