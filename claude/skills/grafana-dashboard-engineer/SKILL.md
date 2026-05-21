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
1. **Detect project structure** — Check for Ansible roles, grafana directories, Docker Compose, etc.
   - Display detected location to user (e.g., "Detected Ansible structure. Dashboard will go in roles/grafana/files/dashboards/")
   - If Ansible detected, ask for category (security, firewall, observability, etc.)
2. Accept application name or system to monitor (e.g., "proxmox", "docker", "emby")
3. Check for existing application template
   - If found: Present template with all available metrics and ask for confirmation
   - If not found: Research via web search + repo inspection, generate comprehensive template
4. Gather requirements via AskUserQuestion:
   - What's the primary use case? (Performance? Availability? Cost? Logs?)
   - Who's the audience? (DevOps, Developers, Executives, On-call?)
   - What dashboard sophistication? (Simple, Comprehensive, Advanced with Alerts, Executive-ready?)
   - Any custom metrics, alert thresholds, or specific drill-downs needed?
   - Refresh cadence and related dashboards in this project?
5. Design dashboard wireframe and present layout options
6. Build dashboard JSON with PromQL/LogQL queries
7. Create feature branch worktree with dashboard definition
8. Test queries against running Grafana instance
9. Generate comprehensive markdown documentation:
   - Extract all metrics and queries from dashboard JSON
   - Document intent, structure, and use cases (from requirement gathering)
   - Create metric definitions with interpretation guidance
   - Generate alert rules table
   - Write usage guide and troubleshooting section
   - Save to appropriate location based on project structure
10. Offer deployment to live Grafana for user confirmation
11. Prepare documentation + dashboard JSON for ship-to-dev

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
1. **Detect project structure** and locate existing dashboard
   - Search in order: Ansible roles → grafana/ → Docker compose → default
   - Confirm location with user (e.g., "Found fail2ban-security-ops in roles/grafana/files/dashboards/security/")
2. Fetch dashboard from repo and live Grafana API
3. Parse change request (add panels, update queries, change thresholds, etc.)
4. Validate changes against templates and best practices
5. Show diff between current and proposed state
6. Create worktree branch for modifications
7. Test queries in Grafana before committing
8. Update dashboard JSON with modifications
9. Update corresponding documentation:
   - Modify metric definitions if queries changed
   - Update alert rules table if thresholds changed
   - Add new sections for new panels
   - Update changelog entry with change description
   - Set `last_modified` to current date
   - Keep documentation in same project structure as dashboard JSON
10. Test both dashboard and documentation in context
11. Offer ship-to-dev after user confirms

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

### /list-dashboards [--filter application|status|category|location]

**Purpose:** Inventory all dashboards with health status and metadata across all project locations.

**Scanning:**
- Scans all known dashboard locations: `roles/grafana/files/dashboards/`, `grafana/dashboards/`, `monitoring/grafana/dashboards/`
- Shows dashboard location (Ansible role, project-root, Docker location, etc.)
- Groups by location for easy reference

**Output:**
- Dashboard name, application/category, and location
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

### Project Structure Detection

The skill automatically detects the project's expected structure and places dashboards accordingly. Detection flow:

1. **Check for Ansible roles structure** (`roles/` directory exists)
   - If Grafana role exists at `roles/grafana/files/dashboards/`:
     - Dashboards → `roles/grafana/files/dashboards/<category>/<name>.json`
     - Documentation → `roles/grafana/files/dashboards/<name>.README.md`
     - Categories: security, firewall, dns, observability, identity, caching, etc.

2. **Check for project-root grafana directory**
   - If `grafana/dashboards/` exists:
     - Dashboards → `grafana/dashboards/<name>.json`
     - Documentation → `grafana/docs/<name>.md`
     - This is the "lightweight" structure for non-Ansible projects

3. **Check for Docker/Compose structure**
   - If `docker-compose.yml` and no roles/ directory:
     - Dashboards → `monitoring/grafana/dashboards/<name>.json`
     - Documentation → `docs/dashboards/<name>.md`

4. **Fallback to standard location**
   - Dashboards → `grafana/dashboards/<name>.json`
   - Documentation → `grafana/docs/<name>.md`
   - Creates directories if they don't exist

### Example: Repository Structures

**Ansible-based (AC_OPBTA pattern):**
```
<project>/
├── roles/
│   └── grafana/
│       └── files/dashboards/
│           ├── security/
│           │   └── fail2ban-security-ops.json
│           ├── firewall/
│           │   └── network-health.json
│           ├── fail2ban-security-ops.README.md
│           └── network-health.README.md
├── grafana/
│   ├── dashboards/
│   │   └── [project-specific dashboards]
│   └── docs/
│       └── [project-specific dashboard docs]
```

**Lightweight (non-Ansible):**
```
<project>/
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
│       └── ... [deleted dashboard backups]
├── docs/
│   └── dashboards/
│       ├── proxmox-infrastructure.md
│       └── ... [alternative doc location]
```

**Docker Compose (monitoring-specific):**
```
<project>/
├── docker-compose.yml
├── monitoring/
│   └── grafana/
│       └── dashboards/
│           ├── app-dashboard.json
│           └── ... [dashboards]
├── docs/
│   └── dashboards/
│       ├── app-dashboard.md
│       └── ... [dashboard docs]
```

### Structure Detection Algorithm

When `/new-dashboard` or `/update-dashboard` is invoked, the skill runs:

```
1. Check if roles/grafana/files/dashboards/ exists
   ├─ YES: Ansible project detected
   │  └─ Ask: What category? (security, firewall, dns, observability, identity, caching, etc.)
   │     → Store in roles/grafana/files/dashboards/<category>/<name>.json
   │     → Document as roles/grafana/files/dashboards/<name>.README.md
   │
   └─ NO: Continue to step 2

2. Check if grafana/dashboards/ exists
   ├─ YES: Lightweight grafana structure detected
   │  └─ Store in grafana/dashboards/<name>.json
   │     Document in grafana/docs/<name>.md
   │
   └─ NO: Continue to step 3

3. Check if docker-compose.yml exists AND no roles/ directory
   ├─ YES: Docker Compose structure detected
   │  └─ Store in monitoring/grafana/dashboards/<name>.json
   │     Document in docs/dashboards/<name>.md
   │
   └─ NO: Continue to step 4

4. Default: Lightweight structure
   └─ Create grafana/dashboards/ if needed
      Store in grafana/dashboards/<name>.json
      Document in grafana/docs/<name>.md
```

**User Override:**
- If user specifies a path during `/new-dashboard --path <custom/path>`, use that explicitly
- Display detected location to user before confirming

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

### Dashboard Documentation (Markdown)

Each dashboard automatically generates corresponding documentation in `/docs/dashboards/<dashboard-name>.md`. This markdown file serves as the source of truth for understanding and maintaining the dashboard.

#### Documentation Structure

```markdown
---
title: [Dashboard Name]
application: [app-name]
category: [category]
created_date: [YYYY-MM-DD]
last_modified: [YYYY-MM-DD]
managed_by: grafana-dashboard-engineer-skill
---

## Overview
[1-2 sentence description of what this dashboard monitors and why it matters]

## Intent & Use Cases
- **Primary Use Case**: What is this dashboard primarily used for?
- **Audience**: Who uses this dashboard? (DevOps, Developers, On-call, Executives?)
- **Refresh Cadence**: How often should this be checked? (Real-time, hourly, daily?)
- **Related Dashboards**: Links to complementary dashboards

## Dashboard Structure

### Overview Section
[Description of top-level health panels and what they indicate]

### Performance Metrics
[Description of performance-related panels, what good/bad looks like]

### Availability & Health
[Description of availability indicators and alert thresholds]

### Custom Sections
[Any application-specific sections with context]

## Metric Definitions

### CPU Usage
- **Query**: [PromQL query]
- **Unit**: Percentage (%)
- **What it measures**: Description of what this metric shows
- **Interpretation**:
  - Green (< 50%): Healthy, plenty of headroom
  - Yellow (50-80%): Approaching limits, monitor trend
  - Red (> 80%): Critical, action needed
- **Common causes when high**: [List of likely causes]
- **Action items when high**: [What to do]

### Memory Usage
- **Query**: [PromQL query]
- **Unit**: Bytes / Percentage
- **What it measures**: Description
- **Interpretation**: Green/Yellow/Red thresholds
- **Common causes when high**: [Causes]
- **Action items when high**: [Actions]

### [Additional metrics...]

## Alert Rules

| Alert Name | Condition | Threshold | Duration | Severity |
|---|---|---|---|---|
| High CPU Usage | CPU > X% | 85% | 5min | Critical |
| Memory Saturation | Memory > Y% | 90% | 10min | Warning |

## Usage Guide

### How to Read This Dashboard
1. Start with the top-left Overview section to understand overall health
2. Drill down into Performance Metrics to diagnose issues
3. Check Alert Rules section for current active alerts
4. Use related dashboards for context

### Common Questions & Answers

**Q: What does this metric mean?**
A: [Answer with reference to Metric Definitions section]

**Q: Why is my alert firing?**
A: [Common causes and troubleshooting steps]

**Q: How do I fix [common issue]?**
A: [Troubleshooting steps and references]

## Troubleshooting

### Dashboard shows no data
- Check datasource connectivity (Prometheus/Loki status)
- Verify application is running and exporting metrics
- Check time range selection (may be outside data retention window)

### Queries are slow
- Review PromQL optimization in Metric Definitions
- Check if high-cardinality labels are causing issues
- Consider increasing query time range

### Alert is misconfigured
- Verify threshold makes sense for your environment
- Check alert notification channels are configured
- Review runbook for escalation procedures

## Related Dashboards
- [Dashboard Name](link) — Context about related dashboard

## Maintenance & Updates

- **Last verified**: [Date when queries were tested against live data]
- **Update frequency**: [How often this dashboard should be reviewed]
- **Owner**: [Team or person responsible]
- **Changelog**:
  - [2026-05-06] Initial dashboard creation
  - [YYYY-MM-DD] Description of changes

## References
- [Official documentation link](https://...)
- [Grafana community dashboard](https://...)
- [Related runbooks/playbooks](link)
```

#### Documentation Generation Workflow

When running `/new-dashboard` or `/update-dashboard`:

1. **Gather Intent Information** via AskUserQuestion:
   - Primary use case and audience
   - Refresh cadence and expected users
   - Related dashboards in the project
2. **Extract Metrics from Dashboard JSON**:
   - Parse all PromQL/LogQL queries
   - Identify metric names and units
   - Determine alert thresholds
3. **Generate Metric Definitions Section**:
   - For each metric, document:
     - The PromQL/LogQL query used
     - Unit of measurement
     - What it measures and why it matters
     - Interpretation guidance (healthy vs critical ranges)
     - Common causes when values are concerning
     - Action items for remediation
4. **Create Alert Rules Table**:
   - Extract all alert conditions
   - Organize by severity and metric
   - Document trigger thresholds and durations
5. **Write Usage Guide**:
   - Explain logical flow through dashboard
   - Common questions and troubleshooting
   - Links to related dashboards
6. **Save to `/docs/dashboards/`**:
   - File naming: `<dashboard-name>.md` (same as JSON file, different extension)
   - Include full frontmatter with metadata
   - Always sync with dashboard updates

#### Keeping Documentation in Sync

- Whenever `/update-dashboard` modifies queries, thresholds, or panels:
  1. Update corresponding `.md` file with new metric definitions
  2. Add changelog entry at bottom
  3. Update `last_modified` date in frontmatter
- Documentation is version-controlled alongside dashboard JSON
- Documentation and dashboard JSON should never drift

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

1. **Detect project structure** and determine target location
2. Create worktree branch: `feat/dashboard-[appname]-[date]`
3. Generate dashboard JSON and store in detected location:
   - Ansible: `roles/grafana/files/dashboards/<category>/<name>.json`
   - Project-root: `grafana/dashboards/<name>.json`
   - Docker: `monitoring/grafana/dashboards/<name>.json`
   - Custom: user-specified path
4. Generate markdown documentation in paired location:
   - Ansible: `roles/grafana/files/dashboards/<name>.README.md`
   - Project-root: `grafana/docs/<name>.md`
   - Docker: `docs/dashboards/<name>.md`
   - Include intent, structure, use cases from requirements gathering
   - Document all metrics with queries, units, and interpretation guidance
   - Create alert rules reference table
   - Add usage guide and troubleshooting section
5. Test queries against running Grafana instance (validate all return data)
6. Verify documentation accuracy by reviewing against live dashboard
7. Show user preview of both dashboard and documentation (with locations highlighted)
8. User confirms dashboard is working, useful, well-documented, and in the right place

### Deployment to Live Grafana

Once user confirms dashboard is working:
1. Deploy to running Grafana instance via API
2. User tests dashboard in live environment
3. Validates queries, alert thresholds, and usability
4. Confirms before proceeding to ship-to-dev

---

## Dashboard Location & Structure Detection

### How the Skill Finds the Right Place

Every time you run `/new-dashboard` or `/update-dashboard`, the skill:

1. Examines your project structure to determine the "dashboard home"
2. Shows you the detected location before proceeding
3. Allows manual override with `--path` flag if needed

This ensures dashboards are stored alongside related configs, templates, and Ansible roles where they belong.

### Structure Priority (in order of detection)

**1. Ansible Roles (Priority High)**
```bash
# Detected when: roles/grafana/files/dashboards/ exists
# Placement: roles/grafana/files/dashboards/<category>/<name>.json
# Documentation: roles/grafana/files/dashboards/<name>.README.md
# When to use: Infrastructure-heavy projects with Ansible orchestration
```

**2. Project-Root Grafana Directory (Priority Medium)**
```bash
# Detected when: grafana/dashboards/ exists AND no Ansible roles/
# Placement: grafana/dashboards/<name>.json
# Documentation: grafana/docs/<name>.md
# When to use: Projects with dedicated grafana/ structure
```

**3. Docker Compose Monitoring (Priority Medium)**
```bash
# Detected when: docker-compose.yml exists AND no roles/
# Placement: monitoring/grafana/dashboards/<name>.json
# Documentation: docs/dashboards/<name>.md
# When to use: Docker-based applications with monitoring stack
```

**4. Fallback (Always Works)**
```bash
# Detected when: none of the above exist
# Placement: grafana/dashboards/<name>.json
# Documentation: grafana/docs/<name>.md
# Creates directories automatically
```

### Manual Override

If auto-detection doesn't match your project structure, override explicitly:

```bash
/new-dashboard fail2ban --path roles/grafana/files/dashboards/security
# Directly specify where to store the dashboard
```

### Category Selection (Ansible-Only)

When Ansible structure is detected, the skill asks:

```
Which category? 
  □ security
  □ firewall
  □ dns
  □ observability
  □ identity
  □ caching
  □ infrastructure
  □ application
  □ database
  □ custom
```

Dashboards are stored in `roles/grafana/files/dashboards/<category>/<name>.json` for easy Ansible role organization.

### Documentation Placement

Documentation always follows the dashboard:

| Dashboard Location | Documentation Location |
|---|---|
| `roles/grafana/files/dashboards/<cat>/<name>.json` | `roles/grafana/files/dashboards/<name>.README.md` |
| `grafana/dashboards/<name>.json` | `grafana/docs/<name>.md` |
| `monitoring/grafana/dashboards/<name>.json` | `docs/dashboards/<name>.md` |

Documentation files are named to be discoverable near the dashboards (especially `.README.md` for Ansible roles, which convention tools recognize).

### Ship-to-Dev Workflow

After user approves:
1. Commit changes to feature branch (atomic commit per dashboard)
2. Create PR to `dev` branch with comprehensive description
3. Include test plan verifying dashboard functionality and documentation completeness
4. Merge after approval
5. Cleanup feature branch
6. Dashboard and documentation now available to entire team

**Commit Message Format:**
```
feat: Add [Application] dashboard

Adds comprehensive monitoring dashboard and documentation for [Application Name].

Includes:
- [X] panels covering [main categories]
- [Y] PromQL/LogQL queries
- [Z] alert rules with thresholds
- Markdown documentation

Location: [roles/grafana/files/dashboards/[category]/[name].json OR grafana/dashboards/[name].json]
Complexity: [Simple|Comprehensive|Advanced]
Application: [app-name]
Categories: Infrastructure, Performance Metrics

Test Plan:
- [x] Dashboard loads without errors
- [x] All [Y] queries return data
- [x] Alert thresholds verified as reasonable
- [x] Dashboard renders correctly on mobile
- [x] Drill-down panels work as expected
- [x] Documentation reflects dashboard state
- [x] All metrics documented with interpretation guidance
- [x] Usage guide is clear and helpful
- [x] Dashboard placed in correct project location
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

### Scenario 1: Adding Fail2ban Dashboard to Ansible Project

```
User: /new-dashboard fail2ban
Claude: Detected Ansible project structure (roles/grafana/files/dashboards/).
Claude: Which category should this dashboard go in?
  □ security (✓ recommended for fail2ban)
  □ firewall
  □ identity
  □ infrastructure
  □ other
User: security
Claude: Searching for fail2ban template... Not found. Researching...
Claude: Generated fail2ban template covering:
  □ Failed login attempts by source
  □ Banned IPs and ban duration
  □ Active jails and protection status
  □ Recidivism patterns
User: All, plus alert on ban rate spikes
Claude: Few quick questions...
  - Who uses this? (Security team, ops, both?)
  - Real-time alerts or review dashboard?
Claude: Building fail2ban dashboard...
[Creates worktree, generates fail2ban-security-ops.json in roles/grafana/files/dashboards/security/]
[Generates fail2ban-security-ops.README.md in roles/grafana/files/dashboards/]
Claude: Preview ready. Location: roles/grafana/files/dashboards/security/
Claude: Dashboard shows ban activity, threat patterns, and protection status.
User: Perfect, deploy it
Claude: Dashboard deployed to live Grafana. Ready to ship to dev?
User: Yes
[Creates PR with dashboard + docs in Ansible structure, merges after approval]
```

### Scenario 2: Adding Dashboard to Lightweight Grafana Project

```
User: /new-dashboard proxmox
Claude: Detected lightweight grafana structure (grafana/dashboards/).
Claude: Searching for Proxmox template... Found!
Claude: Here's what we can monitor:
  □ VM performance (CPU, memory, disk, network)
  □ Container stats (LXC metrics)
  □ Storage and I/O
  □ Cluster health
User: All
Claude: Few quick questions...
[Quick Q&A]
Claude: Building Proxmox dashboard...
[Creates worktree, generates proxmox-infrastructure.json in grafana/dashboards/]
[Generates proxmox-infrastructure.md in grafana/docs/]
Claude: Preview ready. Location: grafana/dashboards/
Claude: Ready to deploy?
User: Yes
[Deploys, ships to dev]
```

### Scenario 3: Updating Fail2ban Dashboard (Ansible Project)

```
User: /update-dashboard fail2ban "add geographic heatmap, lower alert threshold from 100 to 50 bans/hour"
Claude: Detected Ansible project. Found fail2ban in roles/grafana/files/dashboards/security/
Claude: Proposed changes:
  + Add geographic heatmap of ban sources
  ~ Lower ban rate alert: 100/hr → 50/hr
Claude: Testing queries in live Grafana... ✅ Valid
User: Deploy
[Deploys to live Grafana, updates documentation with new metrics and alert threshold]
User: Looks good
Claude: Shipping to dev...
[Creates PR with updated dashboard and README.md]
```

### Scenario 4: Discovering Monitoring Gaps

```
User: /list-dashboards --filter status:warning
Claude: Found 2 dashboards with warnings:

1. roles/grafana/files/dashboards/security/ - fail2ban ⚠️ Queries slow
2. grafana/dashboards/ - docker-containers 🔄 Drift detected (3 live changes)

User: /audit-dashboard fail2ban
Claude: Auditing fail2ban dashboard...
⚠️ 2 PromQL queries could be optimized (missing rate())
⚠️ Missing documentation for custom variables
🔴 Ban rate threshold (50/hr) seems low—queries only return 10-20 events/hour
Claude: Want to optimize?
User: Yes
Claude: Building update...
[Optimizes queries, adjusts thresholds, updates README.md, ships to dev]
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
