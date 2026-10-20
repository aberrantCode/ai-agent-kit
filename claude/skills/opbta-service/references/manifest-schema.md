# manifest-schema.md — `services.yml` schema + the `source:` block

Metadata source of truth is `AC_OPBTA/inventory/services.yml`. Every internal
service is one key under `services:`. The dispatcher **reads** this catalog to
resolve a service and **writes** a catalog row (via AC_OPBTA's own command) when
creating one. Source repos carry only a `.opbta-service` breadcrumb (slug only).

## Per-service fields

Verified against live entries (`pihole`, `grafana`, `taxes`). Not every field
applies to every service; populate what the service needs.

| Field | Example | Notes |
|---|---|---|
| `type` | `docker` \| `lxc` \| `vm` | Deployment target. Drives the apply path (see `lifecycle-map.md`). |
| `host` | `ac-docker1` | Host the service runs on. |
| `stack` | `taxes` | Docker stack dir under `/opt/docker/<stack>/` (docker services with a dedicated stack). |
| `ip` | `192.168.30.156` | VLAN-30 pin. Must respect the carve-out lint (`scripts/check-vlan30-ip-carveout.sh`). |
| `port` / `proto` | `8080` / `http` | Upstream port + scheme Traefik targets. |
| `zone` / `fqdn` | `svc.opbta.com` / `taxes.svc.opbta.com` | Internal zone + CNAME. |
| `expose_public` / `public_fqdn` | `true` / `taxes.opbta.com` | Public surface via Cloudflare tunnel (omit `public_fqdn` when private). |
| `public_geo_policy` | `us-only-block` | WAF geo policy for public services. |
| `via_proxy` | `true` | Routed through Traefik. |
| `dns_mode` | `cname_to_proxy` | How the DNS record is shaped. |
| `auth` | `authentik` \| `oidc` \| (none) | Auth mode. `authentik` = forward-auth outpost; `oidc` adds an Authelia/Authentik client. |
| `monitor` / `logs` | `true` | Prometheus scrape + Promtail log pickup. |
| `category` / `tier` | `utility` / `"3 applications"` | Catalog grouping. |
| `vlan` | `servers` | VLAN name (maps to 192.168.30.0/24). |
| `groups` | `[tax-accountants]` | Authentik access groups. |
| `display_name` / `url_path` | `"Tax Reading Room"` / `/admin` | Dashboard tile label + deep link. |
| `extra_ports` | `[{port: 9617, label: pihole_exporter}]` | Additional exposed ports (exporters, etc.). |
| `traefik_skip_tls_verify` / `traefik_rate_limit_admin` | `true` | Per-router Traefik toggles. |
| `edge_cache_bypass` / `edge_disable_optimizations` | `true` | Cloudflare edge hardening for sensitive public surfaces. |
| `os` | `"Alpine Linux v3.24"` | Pinned to the running container's `PRETTY_NAME` so the os-refresh can't mutate the catalog hash mid-deploy (ISSUE-115). |
| `notes` | free text | Human context; no parser depends on it. |
| `source` | see below | Provenance for services built off-host. |

## The `source:` block — off-host / registry-less provenance

A service whose image is **not** pulled from a registry — built on the
workstation from a source checkout and shipped to the host via
`docker save | gzip | ssh | docker load` — records its provenance here so the
update path knows there is no registry/digest to resolve:

```yaml
source: {repo: "https://github.com/aberrantCode/tax-research", build: host, delegate: true}
```

| Key | Meaning |
|---|---|
| `repo` | Upstream source checkout the image is built from. The GitHub **release tag** is the version source (not a registry tag list). |
| `build: host` | Built off-host on the workstation, not pulled. |
| `delegate: true` | The deploy delegates the build+ship to the source repo's own `scripts/deploy-<slug>.sh`. |

Implications the update path must honour (full detail in AC_OPBTA
`update-service.md` Step 3d / 4c):

- **No digest.** `scripts/check-image-digests.py` does not apply — don't run it,
  don't "fix" its silence.
- **The tag is the only cache key and it is sticky.** The host skips build+load
  when the tag already exists, comparing nothing. **Never reuse a tag across
  different source** — bump the tag for any change, even a one-liner, or the host
  silently keeps serving the old image while every log and `docker inspect`
  reports the new tag.

## The `.opbta-service` breadcrumb (source-repo side)

A one-line file at the source repo root holding **only the slug**:

```
taxes
```

Zero metadata leakage — all real metadata lives in `services.yml`. The dispatcher
uses the breadcrumb to resolve which catalog entry a repo maps to (see
`routing.md` target resolution).
