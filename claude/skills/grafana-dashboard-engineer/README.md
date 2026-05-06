# Grafana Dashboard Engineer

Production-grade Grafana observability dashboard engineering skill. Enables rapid research, design, build, deployment, and validation of monitoring dashboards for Prometheus, Loki, and custom datasources.

## Commands

- `/new-dashboard [app]` — Create dashboard with interactive requirements gathering
- `/update-dashboard [name] [changes]` — Modify existing dashboard with change tracking
- `/remove-dashboard [name]` — Delete dashboard safely with backup
- `/audit-dashboard [name]` — Validate dashboard configuration and queries
- `/list-dashboards [--filter]` — Inventory all dashboards with health status

## Quick Start

1. Ensure Grafana instance is running and accessible
2. Set environment variables:
   ```bash
   export GRAFANA_URL="https://grafana.example.com"
   export GRAFANA_API_KEY="glsa_xxxxxxxxxxxxx"
   ```
3. Use a command:
   ```
   /new-dashboard proxmox
   ```

## Templates

Application-specific monitoring templates are stored in this directory:
- `PROXMOX.md` — Hypervisor and VM monitoring
- `DOCKER.md` — Container and image monitoring
- `OPNSENSE.md` — Firewall and network monitoring
- `EMBY.md` — Media server monitoring
- ... more to be added as needed

## See Also

- `SKILL.md` — Full skill documentation
- Project's `grafana/dashboards/` — Dashboard JSON definitions
- Project's `grafana/docs/` — Dashboard documentation

## When to Use

✅ Creating/updating Grafana dashboards  
✅ Designing observability for applications  
✅ Investigating monitoring gaps  
✅ Optimizing alert thresholds  
✅ Documenting monitoring strategy  

❌ General Grafana administration  
❌ Datasource configuration  
❌ Incident response (use for observability insights only)
