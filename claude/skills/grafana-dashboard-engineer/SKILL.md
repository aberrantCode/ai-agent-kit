---
name: grafana-dashboard-engineer
description: >
  Production-grade Grafana dashboard engineer. Enables rapid research, design, build, deployment, 
  and validation of observability dashboards across Prometheus, Loki, and custom datasources. Supports 
  IaC (Ansible/PowerShell), application-specific templates, and full git workflow integration for 
  homelab and enterprise environments.
version: 1.0.0
status: active
tags: [grafana, prometheus, loki, observability, dashboards, monitoring, iac, ansible, powershell]
requires: []
---

## Overview

The Grafana Dashboard Engineer skill embues Claude Code with production-grade observability expertise across Grafana, Prometheus, Loki, Ansible, PowerShell, and industry best practices. It enables full-lifecycle dashboard management: research → document → design → build → deploy → validate → ship.

### Key Capabilities

**Domain Expertise:**
- Grafana dashboard design patterns and JSON configuration (8.0+, tested on 10.x)
- PromQL query optimization and Prometheus metrics
- LogQL patterns and Loki log aggregation strategies
- Application-specific monitoring templates (Proxmox, Docker, OPNsense, EMBY, Kubernetes, Databases, etc.)
- Linux and Windows monitoring (Prometheus node exporter, Windows Exporter, WMI)
- Infrastructure-as-Code deployment via Ansible and PowerShell
- Business intelligence and SLO/SLA tracking
- Shell scripting and metric collection automation

**Workflow Integration:**
- Interactive requirements gathering (AskUserQuestion)
- Feature branch worktree for isolation
- Dashboard JSON versioning in repo
- Live Grafana API sync and validation
- Ship-to-dev integration for PR-based deployment
- Alert rule management and threshold validation

**Application Templates:**
- Searchable library of pre-built monitoring patterns
- Automatic template research for unknown applications
- Template expansion based on user feedback
- Comprehensive metric coverage documented

---

## Slash Commands

### /new-dashboard [application-name]

**Purpose:** Create a new dashboard from scratch with interactive guidance.

**Prerequisites:**
- Grafana instance running and accessible
- Grafana API key configured (passed via environment or user)
- Datasources (Prometheus, Loki, etc.) pre-configured in Grafana
- Application must be running or have metrics/logs available

**Flow:**
1. Accept application name or system to monitor (e.g., "proxmox", "docker", "emby")
2. Check for existing application template
   - If found: Present template with all available metrics and ask for confirmation
   - If not found: Research via web search + repo inspection, generate comprehensive template
3. Gather requirements via AskUserQuestion:
   - What's the primary use case? (Performance? Availability? Cost? Logs?)
   - Who's the audience? (DevOps, Developers, Executives, On-call?)
   - What dashboard sophistication? (Simple, Comprehensive, Advanced with Alerts, Executive-ready?)
   - Any custom metrics, alert thresholds, or specific drill-downs needed?
4. Design dashboard wireframe and present layout options
5. Build dashboard JSON with PromQL/LogQL queries
6. Create feature branch worktree with dashboard definition
7. Test queries against running Grafana instance
8. Offer deployment to live Grafana for user confirmation
9. Generate documentation and prepare for ship-to-dev

**Example:**
```
User: /new-dashboard proxmox
Claude: Checking for Proxmox template... Found!
Claude: Let me show you monitoring options...
[Presents PROXMOX template with metric categories]
Claude: Which categories interest you? 
  □ Host CPU/Memory/Disk
  □ VM Performance
  □ Storage & I/O
  □ Network Metrics
  □ LXC Container Stats
  □ Cluster Health
User: All, plus alerts
Claude: Quick questions about your environment...
[Interactive Q&A]
Claude: Building comprehensive Proxmox dashboard...
[Creates worktree, generates JSON, tests in Grafana]
Claude: Dashboard ready for review. Deploy to live Grafana?
```

### /update-dashboard [dashboard-name] [changes]

**Purpose:** Modify an existing dashboard with change tracking.

**Flow:**
1. Fetch dashboard from repo and live Grafana API
2. Parse change request (add panels, update queries, change thresholds, etc.)
3. Validate changes against templates and best practices
4. Show diff between current and proposed state
5. Create worktree branch for modifications
6. Test queries in Grafana before committing
7. Update dashboard JSON and documentation
8. Offer ship-to-dev after user confirms

**Example:**
```
User: /update-dashboard proxmox "add CPU hotspot heatmap, increase alert from 80% to 85%"
Claude: Fetching current dashboard...
Claude: Proposed changes:
  + Add CPU usage heatmap panel (sorted by highest usage)
  ~ Update CPU alert threshold: 80% → 85%
[Shows preview]
User: Looks good
Claude: Testing queries in live Grafana... ✅ All valid
Ready to deploy?
```

### /remove-dashboard [dashboard-name]

**Purpose:** Delete a dashboard safely with validation and cleanup.

**Flow:**
1. Confirm dashboard exists in repo and live Grafana
2. List dependent resources:
   - Alert rules referencing this dashboard
   - Documentation links
   - Related exports/backups
3. Ask for confirmation with impact details
4. Remove from repo, commit change
5. Delete from live Grafana instance
6. Archive backup in `.archive/` directory
7. Generate cleanup summary

**Example:**
```
User: /remove-dashboard old-test-dashboard
Claude: Found "old-test-dashboard" in repo and Grafana.
Claude: Impact:
  - 2 alert rules (will become orphaned)
  - Reference in README.md
  - 1 backup created
Confirm deletion?
User: Yes
[Deletes, archives backup, commits changes]
```

### /audit-dashboard [dashboard-name]

**Purpose:** Validate dashboard configuration, queries, and best practices.

**Checks:**
- JSON syntax and Grafana schema compliance
- PromQL query validity and performance
- LogQL syntax correctness
- Variable binding and template expansion
- Alert threshold reasonableness
- Datasource availability and connectivity
- Panel layout and readability
- Naming conventions consistency
- Documentation completeness
- Comparison with stored repo version (detect drift)

**Output:**
- ✅ Passed checks
- ⚠️ Warnings (suboptimal queries, missing docs)
- 🔴 Errors (schema violations, unreachable datasources)
- 📊 Metrics: Panel count, query count, alert count, datasource usage

**Example:**
```
User: /audit-dashboard proxmox
Claude: Auditing Proxmox dashboard...
✅ JSON schema valid
✅ 12/12 PromQL queries valid
✅ All datasources reachable
⚠️ 3 queries could be optimized (missing rate())
⚠️ Missing documentation for 1 custom variable
🔴 CPU alert threshold (95%) too high—recommend 85%
Summary: 16 panels, 14 queries, 2 alerts | Last updated: 3 days ago
```

### /list-dashboards [--filter application|status|category]

**Purpose:** Inventory all dashboards with health status and metadata.

**Output:**
- Dashboard name and application/category
- Status (✅ valid, ⚠️ warnings, 🔴 errors, 🔄 drift detected)
- Panel/query/alert counts
- Last modified date
- Owner (if applicable)

**Filters:**
```
/list-dashboards                           # All dashboards
/list-dashboards --filter application:proxmox  # Only Proxmox
/list-dashboards --filter status:warning   # Dashboards with warnings
/list-dashboards --filter category:infrastructure  # By category
```

**Example:**
```
User: /list-dashboards --filter status:warning
Claude: Dashboard Inventory (2 dashboards with warnings):

1. docker-containers
   ⚠️ Drift detected (3 live changes) | 8 panels | 6 queries
   Last modified: 1 week ago
   Warnings: Missing memory saturation panel

2. opnsense-firewall
   ⚠️ Loki datasource offline | 12 panels | 10 queries
   Last modified: 2 days ago
```

---

## Application Templates

The skill maintains a searchable library of application-specific monitoring templates. Each template documents:
- All possible metrics for that application
- Recommended dashboard layouts and hierarchies
- Best-practice PromQL/LogQL queries with explanations
- Alert threshold recommendations (dev vs prod)
- Links to official documentation
- Community examples and use cases

### Template Discovery Workflow

**When user requests `/new-dashboard [appname]`:**

1. **Search local templates** — Check `<repo>/.claude/skills/grafana-dashboard-engineer/` for `[APPNAME].md`
2. **If found** → Present template to user with metric categories for selection
3. **If not found** → Research phase:
   - Web search official docs, Grafana community, GitHub
   - Inspect repo for existing configs/deployments of that application
   - Query running application's metrics endpoint (if accessible)
4. **Generate comprehensive template** covering all available metrics
5. **Present wireframe to user** for feedback and customization
6. **Create template file** `[APPNAME].md` for future reuse

### Template Structure

```markdown
---
name: Application Name
description: Brief description of application and why monitoring matters
official_docs: https://...
grafana_community: https://...
datasources: [prometheus, loki, etc.]
categories: [infrastructure, application, database, etc.]
---

## Overview
What this application does and key monitoring concerns.

## Available Metrics

### Category 1: Performance Metrics
- metric_name: Description | unit
  - Recommended threshold: X units
  - Alert trigger: when > threshold for Y minutes

### Category 2: Availability Metrics
- metric_name: Description

## Recommended Layouts

### Layout A: Executive Summary (1 page)
Brief description of what it shows.

### Layout B: Detailed Performance (2-3 pages)
Description and metric categories included.

### Layout C: Deep Dive (4+ pages)
Advanced monitoring for troubleshooting.

## PromQL Examples

\`\`\`promql
rate(metric_name[5m]) * 100
\`\`\`

## LogQL Examples

## Alert Rules

## Common Integration Patterns
```

### Pre-built Templates

Initial templates created for common homelab/infrastructure systems:
- **PROXMOX.md** — Hypervisor, VM, LXC, cluster health
- **DOCKER.md** — Containers, images, volumes, network
- **OPNSENSE.md** — Firewall, network interfaces, packet loss, throughput
- **EMBY.md** — Media server, transcoding, library stats
- **WORKSTATION.md** — Windows/Linux desktop monitoring
- **NETWORK.md** — Network topology, link status, quality metrics
- **IOT.md** — Generic IoT sensor data visualization
- **KUBERNETES.md** — K8s clusters, nodes, pods, workloads
- **DATABASE.md** — PostgreSQL, MySQL, MongoDB performance monitoring

---

## Storage & Versioning

### Repository Structure

```
<project>/
├── .claude/skills/
│   └── grafana-dashboard-engineer/
│       ├── SKILL.md (this file)
│       ├── PROXMOX.md (template)
│       ├── DOCKER.md (template)
│       └── ... [other templates]
├── grafana/
│   ├── dashboards/
│   │   ├── proxmox-infrastructure.json
│   │   ├── docker-containers.json
│   │   └── ... [one file per dashboard]
│   ├── docs/
│   │   ├── proxmox-infrastructure.md
│   │   ├── docker-containers.md
│   │   └── ... [dashboard documentation]
│   └── .archive/
│       ├── deleted-dashboard-2026-05-01.json
│       └── ... [deleted dashboard backups]
```

### Dashboard Frontmatter

Each dashboard JSON includes metadata:

```json
{
  "_meta": {
    "grafana_version": "10.0.0",
    "managed_by": "grafana-dashboard-engineer-skill",
    "created_date": "2026-05-06",
    "last_modified": "2026-05-06",
    "application": "proxmox",
    "category": "infrastructure",
    "complexity": "comprehensive",
    "panels_count": 16,
    "queries_count": 14,
    "alerts_count": 2,
    "datasources": ["Prometheus", "Loki"],
    "tags": ["vms", "containers", "storage"]
  },
  ...standard Grafana dashboard JSON...
}
```

---

## Deployment & Integration

### Prerequisites

Before using this skill, ensure:
1. **Grafana instance accessible** and running (8.0+, tested on 10.x)
2. **Grafana API key available** (service account token recommended)
3. **Datasources configured** in Grafana (Prometheus, Loki, etc.)
4. **Application running** or metrics/logs available
5. **Repo writable** for storing dashboards and docs

**Grafana API Key Setup:**
```bash
# Option 1: Service account (recommended)
# In Grafana UI: Admin > Service Accounts > Create service account
# Copy the token

# Option 2: User API key
# In Grafana UI: Account > Preferences > API Keys > New API Key

# Store in environment
export GRAFANA_URL="https://grafana.example.com"
export GRAFANA_API_KEY="glsa_xxxxxxxxxxxxx"
```

### Local Testing & Preview

1. Create worktree branch: `feat/dashboard-[appname]-[date]`
2. Generate dashboard JSON and store in `grafana/dashboards/` directory
3. Generate documentation in `grafana/docs/` directory
4. Test queries against running Grafana instance (validate all return data)
5. Show user preview before committing
6. User confirms dashboard is working and useful

### Deployment to Live Grafana

Once user confirms dashboard is working:
1. Deploy to running Grafana instance via API
2. User tests dashboard in live environment
3. Validates queries, alert thresholds, and usability
4. Confirms before proceeding to ship-to-dev

### Ship-to-Dev Workflow

After user approves:
1. Commit changes to feature branch (atomic commit per dashboard)
2. Create PR to `dev` branch with comprehensive description
3. Include test plan verifying dashboard functionality
4. Merge after approval
5. Cleanup feature branch
6. Dashboard now available to entire team

**Commit Message Format:**
```
feat: Add [Application] dashboard

Adds comprehensive monitoring dashboard for [Application Name].

Includes:
- [X] panels covering [main categories]
- [Y] PromQL/LogQL queries
- [Z] alert rules with thresholds

Complexity: [Simple|Comprehensive|Advanced]
Application: [app-name]
Categories: Infrastructure, Performance Metrics

Test Plan:
- [x] Dashboard loads without errors
- [x] All [Y] queries return data
- [x] Alert thresholds verified as reasonable
- [x] Dashboard renders correctly on mobile
- [x] Drill-down panels work as expected
```

---

## IaC: Ansible & PowerShell

### Ansible Playbook for Dashboard Deployment

Deploy dashboards to managed Grafana instances via Infrastructure-as-Code:

```yaml
---
- name: Deploy Grafana Dashboards
  hosts: grafana_servers
  gather_facts: yes
  
  vars:
    grafana_api_url: "https://{{ grafana_host }}"
    grafana_api_key: "{{ vault_grafana_api_key }}"
    dashboards_dir: "/opt/grafana/dashboards"
  
  tasks:
    - name: Create dashboards directory
      file:
        path: "{{ dashboards_dir }}"
        state: directory
        mode: '0755'
    
    - name: Copy dashboard JSONs
      copy:
        src: "grafana/dashboards/"
        dest: "{{ dashboards_dir }}/"
        mode: '0644'
    
    - name: Deploy dashboards via API
      community.grafana.grafana_dashboard:
        grafana_url: "{{ grafana_api_url }}"
        grafana_api_key: "{{ grafana_api_key }}"
        state: present
        dashboard: "{{ lookup('file', item) | from_json }}"
        overwrite: yes
      loop: "{{ query('fileglob', dashboards_dir + '/*.json') }}"
      register: dashboard_deploy
    
    - name: Verify dashboards deployed
      debug:
        msg: "Deployed {{ dashboard_deploy.results | length }} dashboards"
```

### PowerShell for Windows Monitoring

When dashboard includes Windows-specific metrics (Windows Exporter, WMI):

```powershell
# Deploy Windows Exporter and Grafana dashboard for Windows monitoring
param(
    [string]$GrafanaUrl = "https://grafana.example.com",
    [string]$GrafanaApiKey = $env:GRAFANA_API_KEY,
    [string]$ExporterVersion = "0.21.0"
)

function Install-WindowsExporter {
    param([string]$Version)
    
    $DownloadUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v$Version/windows_exporter-$Version-amd64.exe"
    $InstallerPath = "$env:TEMP\windows_exporter-$Version-amd64.exe"
    
    Write-Host "Downloading Windows Exporter v$Version..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath
    
    Write-Host "Installing Windows Exporter..."
    & $InstallerPath /install
    
    Write-Host "Starting Windows Exporter service..."
    Start-Service -Name "windows_exporter"
}

function Deploy-GrafanaDashboard {
    param([string]$DashboardPath)
    
    $DashboardJson = Get-Content -Path $DashboardPath -Raw | ConvertFrom-Json
    
    $Headers = @{
        "Authorization" = "Bearer $GrafanaApiKey"
        "Content-Type" = "application/json"
    }
    
    $Body = @{
        dashboard = $DashboardJson
        overwrite = $true
    } | ConvertTo-Json -Depth 10
    
    $Response = Invoke-RestMethod `
        -Uri "$GrafanaUrl/api/dashboards/db" `
        -Method POST `
        -Headers $Headers `
        -Body $Body
    
    Write-Host "Dashboard deployed: $($Response.id)"
    return $Response
}

# Main execution
Install-WindowsExporter -Version $ExporterVersion
Deploy-GrafanaDashboard -DashboardPath ".\grafana\dashboards\workstation-monitoring.json"
```

---

## Best Practices Encoded

The skill enforces and teaches industry-standard observability practices:

### 1. Query Optimization
- Recommend `rate()` for counter metrics (avoid raw counters)
- Suggest appropriate time ranges (5m, 15m, 1h based on metric frequency)
- Flag N+1 query patterns and label explosion
- Optimize cardinality in label matching (avoid high-cardinality labels)

### 2. Alert Thresholds
- Base recommendations on industry standards (USE, RED methods)
- Suggest different thresholds for dev vs prod environments
- Warn about overly aggressive thresholds (alert fatigue)
- Include runbook links with each alert rule
- Recommend SLO-based alerting for critical services

### 3. Dashboard UX/Design
- Logical panel ordering (top-left = most important metric)
- Consistent color schemes (green=healthy, amber=warning, red=critical)
- Readable panel titles and descriptions with units
- Mobile-responsive layouts
- Meaningful drill-down paths (panels linking to related dashboards)

### 4. Documentation
- Explain each panel's purpose and how to interpret it
- Document custom variables and their impact
- Link to related dashboards
- Include alert runbooks and escalation paths
- Document when dashboard was last verified

### 5. Monitoring Methodologies
- **RED method** for services: Rate (requests/sec), Errors (error rate %), Duration (latency)
- **USE method** for infrastructure: Utilization (%), Saturation (queue depth), Errors (error count)
- **SLO/SLA tracking** for critical systems
- **Proactive alerting** (alert on trends, not just thresholds)
- **Cost tracking** where applicable (compute hours, data egress, etc.)

---

## Integration with Your Infrastructure

The skill is aware of your environment from the repository:
- Existing deployments (Proxmox, Docker, Kubernetes, etc.)
- Git history patterns (identifies infrastructure changes)
- Application configurations (uses to inform metric selection)
- Current monitoring gaps (suggests dashboards for unmonitored systems)

**When you run `/new-dashboard [app]`, the skill will:**
1. Search repo for existing configs/deployments of that application
2. Check git history for relevant patterns and changes
3. Propose monitoring aligned with your actual infrastructure
4. Suggest complementary dashboards (e.g., "Add OPNsense network metrics to complement Proxmox monitoring?")

---

## Example Workflows

### Scenario 1: Adding EMBY Media Server Dashboard

```
User: /new-dashboard emby
Claude: Searching for EMBY template... Not found. Researching...
Claude: Found EMBY in your docker-compose. Generating template...
Claude: Here's what we can monitor for EMBY:
  □ Playback stats (users, concurrent streams, content)
  □ Server performance (CPU, memory, cache efficiency)
  □ Library health (file counts, organization, errors)
  □ Transcoding load (concurrent sessions, CPU cost)
User: All, especially transcoding
Claude: Few quick questions...
  - Who uses this dashboard? (You, other family members, support team?)
  - What's most important? (Performance? Availability? Cost?)
Claude: Building EMBY dashboard with transcoding focus...
[Creates worktree, generates JSON, tests in live Grafana]
Claude: Preview ready. This shows transcoding activity, library stats, and performance.
User: Perfect, deploy it
Claude: Dashboard deployed. Ready to ship to dev?
User: Yes
[Creates PR with dashboard + docs, merges after approval]
```

### Scenario 2: Optimizing Proxmox Dashboard After Incident

```
User: /update-dashboard proxmox "add network I/O per VM, CPU alert was 95% but we hit limits at 85%"
Claude: Fetching current dashboard...
Claude: Proposed changes:
  + Add network I/O heatmap (sorted by usage)
  ~ Lower CPU alert from 95% to 85%
Claude: Testing queries in live Grafana... ✅ Valid
User: Deploy
[Deploys to live Grafana]
User: Looks good
Claude: Shipping to dev...
[Creates PR with change explanation and test results]
```

### Scenario 3: Discovering Monitoring Gaps

```
User: /list-dashboards --filter status:warning
Claude: Found 2 dashboards with warnings:

1. docker-containers ⚠️ Loki query failing
2. opnsense-firewall ⚠️ Drift detected (3 live changes)

User: /audit-dashboard opnsense-firewall
Claude: Auditing OPNsense dashboard...
🔴 3 live edits not in repo (drift detected)
⚠️ Missing WAN interface packet loss tracking
⚠️ CPU alert threshold might be too high
Claude: Want to fix these?
User: Yes, add WAN tracking
Claude: Building update...
[Updates dashboard, deploys, ships to dev]
```

---

## When to Use This Skill

✅ **Good fit:**
- Creating new Grafana dashboards
- Updating existing dashboards with new metrics
- Designing observability for applications
- Investigating monitoring gaps and blind spots
- Optimizing alert thresholds after incidents
- Documenting monitoring strategy
- Deploying dashboards via IaC

❌ **Not this skill:**
- General Grafana administration (user/org management, permissions)
- Datasource configuration (assume datasources exist and are accessible)
- Incident response triage (use for observability insights, not incident response)
- Log analysis tools (this is dashboard engineering, not log forensics)

---

## Quick Start Checklist

Before using this skill:

- [ ] Grafana instance running and accessible at a URL
- [ ] Grafana API key obtained (service account token recommended)
- [ ] Datasources configured (Prometheus, Loki, etc. as needed)
- [ ] Application running or metrics/logs being collected
- [ ] Repository writable for storing dashboards and docs
- [ ] Environment variables set: `GRAFANA_URL`, `GRAFANA_API_KEY`

**Example setup:**
```bash
export GRAFANA_URL="https://grafana.example.com"
export GRAFANA_API_KEY="glsa_xxxxxxxxxxxxx"
# Then: /new-dashboard proxmox
```

---

## Future Extensions

- Dashboard versioning and rollback to previous versions
- Multi-Grafana instance support (sync dashboards across environments)
- Dashboard sharing registry (community-contributed templates)
- Custom alert notification templates per dashboard
- SLO/SLI calculation helpers with burn rate tracking
- Cost attribution dashboards (cloud spend, compute hours)
- ML-based anomaly detection integration
- Dashboard performance profiling (slow queries, heavy panels)
- Auto-remediation for common misconfiguration patterns
