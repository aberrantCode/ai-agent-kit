---
name: start-app
description: Start any type of modern application — web apps, APIs, full-stack projects, Docker-based stacks, microservices, and more. Use this skill whenever the user wants to run, launch, start, execute, or spin up an application or service. Trigger it even when the user says "start the app", "run it", "boot it up", "kick it off", "get it running", "spin it up", or any similar phrase. Also trigger when the user asks how to run the project, which command starts the UI, how to get the dev environment going, or when a prompt includes a technology name alongside a run/start intent (e.g. "start the Next.js app", "run the FastAPI server", "launch the Docker stack").
---

# Start App

Provides the end-to-end workflow for discovering, selecting, and executing the correct startup procedure for any modern application — then validating success and recovering from failures.

The skill also maintains a per-solution **intelligence cache** at `docs/framework/start-app.md` so subsequent runs skip the expensive discovery pass and go straight to execution. Always begin with **Step 0** below; it decides whether Steps 1–3 are needed at all.

---

## Step 0 — Check the Intelligence Cache

The cache lives at `docs/framework/start-app.md` (repo-relative). It captures every answer the skill previously confirmed for this solution: the authoritative start command, named variants, service URLs/ports, env requirements, success signals, and known failure recoveries. See [Cache file — purpose and structure](#cache-file--purpose-and-structure) at the bottom of this document for the full schema.

Every invocation begins here and resolves into exactly one of three modes.

### Decide the mode

1. Is the file `docs/framework/start-app.md` present in the repo?
   - **No** → **Mode 2 — Generate** (fall through to Step 1, then write the cache at the end of a successful run).
2. Does the user's prompt explicitly request a refresh or update?
   - Match on intents like `--refresh`, `--update`, `regenerate`, `rebuild cache`, `ignore the cached start-app docs`, `my solution changed`, `reinvestigate` → **Mode 3 — Update** (fall through to Step 1 seeded with the existing cache, then rewrite).
3. Read the cache frontmatter. Compare the `generated` timestamp against the mtime of every path listed in `invalidation-watches`. If any watched path is newer, or any is missing entirely, the cache is **stale** → **Mode 3 — Update**.
4. Otherwise the cache is **fresh** → **Mode 1 — Use** (fast path).

### Mode 1 — Use (fast path)

This is the whole point of the cache. When it is fresh:

1. If the user's prompt names a variant (e.g. "start in prod mode", "backend only", "rebuild"), look up the matching row in the *Startup variants* section of the cache. Otherwise use the *Default startup command*.
2. Skip Steps 1 and 2 entirely. Proceed directly to **Step 3 — Execute and Inspect Results** using that command.
3. On success, touch only the cache's `generated` timestamp and append a `Change log` row noting the run. Do not rewrite the rest of the file — its answers are still valid.
4. On failure, consult the cache's *Known failure recoveries* table first. If the error matches a known pattern, apply the recorded fix and retry. If it does not match, treat this as drift and fall through to **Mode 3 — Update**.

Announce the fast path to the user: "Using cached start command from `docs/framework/start-app.md` — run `<command>`." This is how the user learns the cache exists and can intervene if it looks wrong.

### Mode 2 — Generate

The cache does not exist yet. Run Steps 1–3 normally. On a successful start, write `docs/framework/start-app.md` using the template in [Cache file — purpose and structure](#cache-file--purpose-and-structure). Create the `docs/framework/` directory if it does not exist.

### Mode 3 — Update

The cache exists but must be rewritten. Run Steps 1–3 seeded with the previous cache — already-known services, ports, and commands become the working hypothesis rather than a blank slate, so the update is usually faster than a from-scratch generation. On success, rewrite the cache, preserving the existing `Change log` and appending a new row that describes what changed and why.

### When the cache is absent by design

Some repos should not have the cache checked in — e.g. ephemeral sandboxes or scratch repos. If `docs/framework/` is explicitly gitignored or the user says "don't write a cache for this repo", skip the persist step at the end of Step 3b and note the choice in the run summary. Do not create the file silently.

---

## Step 1 — Discover Existing Scripts

Search the repository's `scripts/` directory (relative to the repo root, or `./scripts` from the current working directory) for any file whose name begins with `start`, `run`, `execute`, or `launch` (case-insensitive).

```bash
# Repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Find all candidates
find "$REPO_ROOT/scripts" -maxdepth 2 \( -name "start*" -o -name "run*" -o -name "execute*" -o -name "launch*" \) 2>/dev/null | sort
```

Also check for common top-level files that serve as launchers:
- `docker-compose.yml` / `docker-compose.yaml`
- `Makefile` (look for `start`, `dev`, `run`, `up` targets)
- `package.json` (look for `start`, `dev`, `serve` scripts)
- `Procfile`

Collect everything found into a **candidate list**.

---

## Step 2 — Match Candidates to the User's Intent

If the user provided a prompt (e.g. `/start-app run the backend API`), use it to narrow the candidates:
- Parse for technology names (Next.js, FastAPI, Django, Docker, .NET, Go, etc.)
- Parse for component names (frontend, backend, API, UI, worker, db)
- Filter the candidate list to those whose name or content implies the target

### Case A — No relevant scripts found

No candidates match (or the `scripts/` directory does not exist).

Prompt the user with three options:

1. **Yes, create a script for me** — detect the stack and generate one
2. **No, just run the app directly** — infer the start command from the project
3. **Let me specify the command manually** — accept a command from the user

If option 1 is chosen:
- Ask which directory/project is the **UI** (if the repo is monorepo-style)
- Detect the full stack (see **Stack Detection** below) and generate a startup script in `scripts/` that:
  1. Starts all required infrastructure (databases, message queues, cache layers)
  2. Starts backend/API services
  3. Starts the UI/frontend last
- Save the script as `scripts/Start-App.ps1` (Windows/cross-platform) or `scripts/start-app.sh` (Unix)
- Then proceed to execute it

If option 2 is chosen:
- Detect the stack and run the appropriate start command directly (see **Stack Detection**)

If option 3 is chosen:
- Accept the command from the user and execute it

### Case B — Exactly one relevant script found

Execute it directly, but first:
1. Read the script to understand what it does and what parameters it accepts
2. Check whether the user's prompt implies any parameter overrides (e.g. "start app in production mode")
3. If parameters are needed, pass them; otherwise run as-is

```bash
# Example: PowerShell script
pwsh -NonInteractive -File "$SCRIPT_PATH" [params]

# Example: Bash script
bash "$SCRIPT_PATH" [params]
```

### Case C — Multiple relevant scripts found

Ask the user which one to run, presenting the name and a one-line summary for each candidate.

After the user selects one, read the script to identify its parameters. Then ask:
- **Run with default settings** — no extra parameters
- **Customize parameters** — list each detected parameter with its type, default, and purpose, collect choices, and construct the final command

---

## Step 3 — Execute and Inspect Results

Run the chosen command. Capture both stdout and stderr. For long-running processes (dev servers), let output stream for 10–20 seconds and then evaluate the tail.

```bash
# Capture output to a temp file while also streaming to terminal
OUTFILE=$(mktemp)
<command> 2>&1 | tee "$OUTFILE" &
APP_PID=$!
sleep 15  # wait for startup
```

### Success indicators (stop here — Step 3b)

The app started successfully if the output contains any of:
- `Listening on`, `Running on`, `started`, `ready`, `compiled`, `serving`
- An accessible port number (e.g. `http://localhost:3000`)
- `✓`, `✔`, `SUCCESS`, `ready in`
- Docker: `Started`, `healthy`, container IDs listed without errors
- .NET: `Now listening on:`
- Django/Flask: `Development server is running`
- Go: `Listening and serving`

### Failure indicators (go to Step 3a)

Treat the startup as failed if:
- Process exits with non-zero code before 15 seconds
- Output contains `Error`, `error:`, `EADDRINUSE`, `failed`, `Cannot find`, `ModuleNotFoundError`, `command not found`, `port already in use`, `connection refused`
- Docker: `exited with code`, `unhealthy`
- Any stack trace or exception output

### Step 3a — Failure Recovery

Analyze the error output to determine the root cause. Common patterns:

| Error Pattern | Likely Cause | Suggested Fix |
|---|---|---|
| `EADDRINUSE` / `port already in use` | Port occupied by another process | Kill the process on that port or use a different port |
| `ModuleNotFoundError` / `Cannot find module` | Missing dependencies | Run `npm install` / `pip install -r requirements.txt` / `uv sync` / etc. |
| `command not found` | Missing tool (node, python, docker, etc.) | Install the required runtime |
| `connection refused` / DB connection error | Database/service not running | Start the required dependency first |
| `.env` not found / missing env var | Missing environment config | Create `.env` from `.env.example` or set the missing variable |
| `permission denied` | Script not executable | `chmod +x <script>` |
| Docker: `Cannot connect to Docker daemon` | Docker not running | Start Docker Desktop |

Present the analysis to the user and ask:
- **Yes, fix it automatically** — apply the suggested fix and retry
- **Show me the full error output** — share full output for manual investigation
- **No, leave it for now** — stop here

If the user approves: apply the fix and re-run from Step 3. Limit auto-fix retries to 3 attempts to avoid looping forever.

### Step 3b — Successful Start

Report the success clearly:
- Which URL/port the app is running on
- Which services/processes were started
- Any relevant next steps (e.g. open browser, run migrations first, available API docs)

**Then persist the intelligence cache.** Which write to perform depends on the mode Step 0 resolved to:

| Mode | Action |
|---|---|
| Mode 1 — Use | Update the `generated` timestamp in the frontmatter; append one row to *Change log* describing the run (e.g. `used cached command (variant: dev)`). Leave everything else untouched. |
| Mode 2 — Generate | Create `docs/framework/start-app.md` from scratch using the template in [Cache file — purpose and structure](#cache-file--purpose-and-structure). Populate every section with what was just observed during Steps 1–3. |
| Mode 3 — Update | Rewrite the cache, carrying the prior *Change log* forward and adding a new dated row explaining what changed (new service, changed port, different package manager, newly seen failure recovery, etc.). |

If a new failure pattern was recovered during Step 3a, always add it to the cache's *Known failure recoveries* table — that is the mechanism by which the cache gets smarter over time.

Exit gracefully — do not keep polling or output anything further unless the user asks.

---

## Stack Detection Reference

When no script exists, use this reference to detect and start the appropriate stack.

### Node.js / JavaScript / TypeScript

```bash
# Detect package manager
[ -f pnpm-lock.yaml ] && PM="pnpm" || ([ -f yarn.lock ] && PM="yarn" || PM="npm")

# Read package.json for available scripts
cat package.json | python -c "import sys,json; s=json.load(sys.stdin).get('scripts',{}); [print(k,':',v) for k,v in s.items()]"
```

Priority: `dev` > `start` > `serve`

| Framework | Command |
|---|---|
| Next.js | `npm run dev` (or `next dev`) |
| Vite / React | `npm run dev` |
| Express / Fastify | `npm run dev` or `node src/index.js` |
| Remix | `npm run dev` |
| Astro | `npm run dev` |
| NestJS | `npm run start:dev` |

### Python

```bash
# Detect environment manager
[ -f pyproject.toml ] && grep -q "uv" pyproject.toml && PM="uv run" || PM="python"
[ -f requirements.txt ] && PM="python"
```

| Framework | Command |
|---|---|
| FastAPI | `uv run uvicorn main:app --reload` or `uvicorn app.main:app --reload` |
| Flask | `flask run` or `python app.py` |
| Django | `python manage.py runserver` |
| Streamlit | `streamlit run app.py` |
| Gradio | `python app.py` |

### Docker / Docker Compose

```bash
# Check for compose file
[ -f docker-compose.yml ] || [ -f docker-compose.yaml ] && docker compose up
# With build if first time or images changed:
docker compose up --build
```

For detached + logs: `docker compose up -d && docker compose logs -f`

### .NET

```bash
# Find the main project
find . -name "*.csproj" -not -path "*/obj/*" | head -5

dotnet run --project <ProjectName>
# or for hot-reload:
dotnet watch run --project <ProjectName>
```

### Go

```bash
go run ./cmd/...
# or
go run main.go
```

### Ruby on Rails

```bash
bundle exec rails server
# or: bin/rails s
```

### PHP / Laravel

```bash
php artisan serve
```

### Rust

```bash
cargo run
# or for web services:
cargo watch -x run
```

### Java / Spring Boot

```bash
./mvnw spring-boot:run
# or Gradle:
./gradlew bootRun
```

### Monorepo / Full-Stack Stacks

When a project has multiple services (frontend + backend + DB), the right approach is to start them in dependency order:

1. Infrastructure (Postgres, Redis, etc.) — use Docker Compose services if available
2. Backend / API
3. Frontend / UI

Ask the user which component is the "UI" if ambiguous, then build or run a script that handles all layers.

---

## Script Generation Template

When creating a new `scripts/Start-App.ps1`, follow the patterns below exactly — they are drawn from a production-quality startup script and represent the expected structure for all new scripts.

### How to fill in the template

Before writing a single line of the script, gather this information from the project:

| Question | Where to find it |
|---|---|
| What services does the stack have? | `docker-compose.yml` services block, or directory structure |
| What are the source dirs that feed each Docker image? | Dockerfile `COPY` / `ADD` instructions |
| What port does the API health endpoint live on? | API router or `.env` / config files |
| What port does the web frontend serve on? | `package.json` dev script, nginx config, or `.env` |
| Is there a setup script (first-time only)? | `scripts/setup*` or `scripts/init*` |
| What env vars must be non-empty / non-placeholder? | `.env.example` or docs |
| Is there a Chrome extension? | Look for `extension/` or `chrome-extension/` directory |
| What Docker Compose profiles exist? | `docker-compose.yml` `profiles:` keys |

Use this information to replace every `<PLACEHOLDER>` in the template below.

---

### Full PowerShell template (`scripts/Start-App.ps1`)

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Starts the <PROJECT_NAME> application stack.

.DESCRIPTION
    1. Runs <SETUP_SCRIPT> automatically if first-time setup is needed
       (.env is missing/unconfigured, or Docker images have not been built yet).
    2. Detects whether service images are older than their source files and
       rebuilds automatically if so.
    3. Starts Docker Compose services (<LIST_OF_SERVICES>).
    4. Waits for the API and web dashboard to become healthy.
    [5. Builds the Chrome extension if dist/ is missing or -BuildExtension is set.]  ← include only if extension/ dir exists
    [6. Launches Chrome with the unpacked extension and opens the dashboard.]         ← include only if extension/ dir exists

.PARAMETER NoBrowser
    Start backend services only — do not launch Chrome.           ← include only if extension/ dir exists

.PARAMETER BuildExtension
    Force a rebuild of the extension even if dist/ already exists. ← include only if extension/ dir exists

.PARAMETER Rebuild
    Force a rebuild of Docker images even if they appear current.

.PARAMETER Dev
    Start the Vite dev server (<DEV_PORT>) instead of the production
    container (<PROD_PORT>). Enables hot-module replacement.

.PARAMETER ChromeProfile
    Path to use as Chrome's --user-data-dir. Defaults to a "<PROJECT_SLUG>-dev"  ← include only if extension/ dir exists
    folder inside $env:TEMP so it is isolated from your main profile.

.EXAMPLE
    .\scripts\Start-App.ps1                   # dev mode (HMR) — default
    .\scripts\Start-App.ps1 -Dev:$false       # production build
    .\scripts\Start-App.ps1 -NoBrowser        ← include only if extension/ dir exists
    .\scripts\Start-App.ps1 -BuildExtension   ← include only if extension/ dir exists
    .\scripts\Start-App.ps1 -Rebuild
#>

param(
    [switch]$NoBrowser,                                                        # ← include only if extension/ dir exists
    [switch]$BuildExtension,                                                   # ← include only if extension/ dir exists
    [switch]$Dev = $true,
    [switch]$Rebuild,
    [string]$ChromeProfile = (Join-Path $env:TEMP '<PROJECT_SLUG>-dev')        # ← include only if extension/ dir exists
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "    [OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "    [WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail([string]$Message) {
    Write-Host ""
    Write-Host "    [FAIL] $Message" -ForegroundColor Red
}

# Helper: returns $true if node_modules is missing or older than package.json / package-lock.json
# Use this before any `npm install` call to avoid redundant installs.
function Test-NpmInstallNeeded([string]$Dir) {
    $nodeModules = Join-Path $Dir 'node_modules'
    if (-not (Test-Path $nodeModules)) { return $true }

    $installedTime = (Get-Item $nodeModules).LastWriteTime
    foreach ($manifest in @('package.json', 'package-lock.json')) {
        $file = Join-Path $Dir $manifest
        if ((Test-Path $file) -and (Get-Item $file).LastWriteTime -gt $installedTime) {
            Write-Warn "$manifest is newer than node_modules — running npm install"
            return $true
        }
    }
    return $false
}

$ProjectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $ProjectRoot

# ---------------------------------------------------------------------------
# 1. Detect Docker Compose
# ---------------------------------------------------------------------------

Write-Step "Detecting Docker Compose"

if (-not (Get-Command 'docker' -ErrorAction SilentlyContinue)) {
    Write-Fail "docker not found. Install Docker Desktop and re-run."
    exit 1
}

$ComposeCmd = if (& docker compose version 2>&1 | Select-String 'version') { 'docker compose' } else { 'docker-compose' }
Write-Ok "Using: $ComposeCmd"

# ---------------------------------------------------------------------------
# 2. First-time setup detection
# Run <SETUP_SCRIPT> automatically when:
#   A) .env is missing or has unconfigured placeholder values
#   B) Docker images for key services have never been built
# ---------------------------------------------------------------------------

function Test-SetupRequired {
    # Condition A — .env exists and all required secrets are filled in
    $envFile = Join-Path $ProjectRoot '.env'
    if (-not (Test-Path $envFile)) { return $true }

    $content = Get-Content $envFile -Raw
    # <REQUIRED_ENV_VARS>: list the secret keys that must have real values (not blank, not "changeme")
    foreach ($key in @('<SECRET_KEY_1>', '<SECRET_KEY_2>', '<SECRET_KEY_3>')) {
        if ($content -notmatch "(?m)^${key}\s*=\s*[^`r`n]+") { return $true }
        if ($content -match  "(?m)^${key}\s*=\s*changeme")    { return $true }
    }

    # Condition B — Docker images for key services exist
    # Docker Compose prefixes image names with the lowercased project directory name.
    $projectName = (Split-Path $ProjectRoot -Leaf).ToLower()
    # <KEY_SERVICES>: list service names whose images must exist (e.g. 'api', 'worker')
    $builtImages = & docker images --format '{{.Repository}}' 2>&1 |
                   Where-Object { $_ -match "${projectName}.+(<KEY_SERVICE_1>|<KEY_SERVICE_2>)" }
    if (-not $builtImages) { return $true }

    return $false
}

Write-Step "Checking setup state"

if (Test-SetupRequired) {
    Write-Warn "First-time setup required — launching <SETUP_SCRIPT>"
    Write-Host ""

    $setupScript = Join-Path $PSScriptRoot '<SETUP_SCRIPT>'   # e.g. 'setup-backend.ps1'
    & $setupScript
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "<SETUP_SCRIPT> exited with code $LASTEXITCODE — aborting."
        exit 1
    }

    Write-Host ""
    Write-Step "Resuming Start-App after setup"
} else {
    Write-Ok "Environment configured and images exist — skipping setup"
}

# ---------------------------------------------------------------------------
# 3. Stale image detection + service startup
# Compare each service image's creation timestamp against the source files
# that feed it (Dockerfile, source dirs, dependency manifests).
# Rebuild automatically if anything is newer than the image.
# ---------------------------------------------------------------------------

Write-Step "Starting backend services"

function Test-ImageStale([string]$ServiceName, [string[]]$SourceDirs) {
    # Image name format: <project_dir_lowercase>-<service>   (Docker Compose default)
    $projectName = (Split-Path $ProjectRoot -Leaf).ToLower()
    $imageCreated = & docker inspect --format '{{.Created}}' "${projectName}-${ServiceName}" 2>$null
    if (-not $imageCreated) { return $true }   # image doesn't exist yet
    try { $imageTime = [datetime]::Parse($imageCreated) } catch { return $true }

    foreach ($dir in $SourceDirs) {
        $fullDir = Join-Path $ProjectRoot $dir
        if (-not (Test-Path $fullDir)) { continue }
        $newer = Get-ChildItem -Path $fullDir -Recurse -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -gt $imageTime } |
                 Select-Object -First 1
        if ($newer) {
            Write-Warn "Image '$ServiceName' is stale — $($newer.FullName) is newer"
            return $true
        }
    }
    return $false
}

# <STALE_CHECKS>: one line per service that has a built image.
# List the source dirs/files that, if changed, mean the image needs rebuilding.
# Example pattern — replace service names and source paths for this project:
#   $<SERVICE>Stale = Test-ImageStale '<service>' @('<src_dir>', '<Dockerfile>', '<schema_file>')
$<SERVICE_1>Stale = Test-ImageStale '<service_1>' @('<service_1_src>', '<service_1_dockerfile>')
$<SERVICE_2>Stale = Test-ImageStale '<service_2>' @('<service_2_src>', '<service_2_dockerfile>')

$needsRebuild = $Rebuild -or $<SERVICE_1>Stale -or $<SERVICE_2>Stale
$buildFlag    = if ($needsRebuild) { '--build' } else { '' }
if ($needsRebuild) {
    Write-Host "    [REBUILD] Rebuilding stale Docker images" -ForegroundColor Magenta
}

# ---------------------------------------------------------------------------
# Dev-mode: detect if the web dev container needs force-recreating because
# its package manifests changed since the container last started.
# Only needed when a long-lived dev container manages its own npm install.
# ---------------------------------------------------------------------------

function Test-WebDevRecreateNeeded {
    $containerName = '<PROJECT_SLUG>-<WEB_DEV_SERVICE>-1'   # e.g. 'myapp-web-dev-1'
    $containerStarted = & docker inspect --format '{{.State.StartedAt}}' $containerName 2>$null
    if (-not $containerStarted) { return $false }
    try { $startedTime = [datetime]::Parse($containerStarted) } catch { return $false }

    $webDir = Join-Path $ProjectRoot '<WEB_DIR>'   # e.g. 'web'
    foreach ($manifest in @('package.json', 'package-lock.json')) {
        $file = Join-Path $webDir $manifest
        if ((Test-Path $file) -and (Get-Item $file).LastWriteTime -gt $startedTime) {
            Write-Warn "$manifest is newer than $containerName — will force-recreate"
            return $true
        }
    }
    return $false
}

if ($Dev) {
    Write-Host "    [DEV] Starting with hot-reload dev server on port <DEV_PORT>" -ForegroundColor Magenta
    $webDevFlag = if (Test-WebDevRecreateNeeded) { '--force-recreate' } else { '' }
    # Start all services using the 'dev' profile; the production web container is excluded.
    # Replace service names and profile name to match docker-compose.yml.
    Invoke-Expression "$ComposeCmd --profile dev up -d --remove-orphans $buildFlag $webDevFlag <INFRA_SERVICES> <API_SERVICES> <WEB_DEV_SERVICE>"
} else {
    Invoke-Expression "$ComposeCmd up -d --remove-orphans $buildFlag"
}

if ($LASTEXITCODE -ne 0) {
    Write-Fail "docker compose up failed — check output above"
    exit 1
}

Write-Ok "Containers started (or already running)"

# ---------------------------------------------------------------------------
# 4. Wait for API health endpoint
# Poll until the API reports healthy or the deadline expires.
# ---------------------------------------------------------------------------

Write-Step "Waiting for API to become ready"

$apiReady = $false
$deadline  = (Get-Date).AddSeconds(150)   # adjust if your API starts slowly

# <API_HEALTH_URL>: the full URL of a health/readiness endpoint, e.g. http://127.0.0.1:8000/health
Write-Host "    Polling <API_HEALTH_URL>" -NoNewline

while ((Get-Date) -lt $deadline) {
    try {
        $resp = Invoke-WebRequest -Uri '<API_HEALTH_URL>' `
                    -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($resp -and $resp.StatusCode -eq 200) {
            $apiReady = $true
            Write-Host " ready" -ForegroundColor Green
            break
        }
    } catch { }
    Write-Host '.' -NoNewline
    Start-Sleep -Seconds 2
}

if (-not $apiReady) {
    Write-Host ""
    Write-Warn "API did not respond within 150 s — it may still be starting up."
    Write-Host "    Check logs with: $ComposeCmd logs -f <API_SERVICE>" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 5. [CHROME EXTENSION] Build extension if needed
# Include this entire section only when an extension/ directory exists in
# the project. Delete it otherwise.
# ---------------------------------------------------------------------------

$ExtDir  = Join-Path $ProjectRoot 'extension'   # adjust path if needed
$DistDir = Join-Path $ExtDir 'dist'

$buildMarker = Join-Path $DistDir 'manifest.json'
$needsBuild  = $BuildExtension -or
              (-not (Test-Path $DistDir)) -or
              (-not (Test-Path $buildMarker))

if (-not $needsBuild) {
    $markerTime = (Get-Item $buildMarker).LastWriteTime
    $newerFile  = Get-ChildItem -Path (Join-Path $ExtDir 'src') -Recurse -File |
                  Where-Object { $_.LastWriteTime -gt $markerTime } |
                  Select-Object -First 1
    if ($newerFile) {
        Write-Warn "Extension source newer than last build: $($newerFile.FullName)"
        $needsBuild = $true
    }
}

if ($needsBuild) {
    Write-Step "Building Chrome extension"

    if (-not (Get-Command 'npm' -ErrorAction SilentlyContinue)) {
        Write-Fail "npm not found. Install Node.js 20+ from https://nodejs.org/"
        exit 1
    }

    Push-Location $ExtDir
    try {
        if (Test-NpmInstallNeeded $ExtDir) {
            Write-Host "    Installing npm dependencies..."
            npm install --silent
            if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        }
        Write-Host "    Running build..."
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
    } catch {
        Write-Fail $_.Exception.Message
        Pop-Location
        exit 1
    } finally {
        Pop-Location
    }

    Write-Ok "Extension built -> $DistDir"
} else {
    Write-Ok "Extension dist/ is up to date — skipping build (use -BuildExtension to force)"
}

# ---------------------------------------------------------------------------
# 6. [CHROME LAUNCH] Find Chrome and open the dashboard
# Include this section only when an extension/ directory exists.
# ---------------------------------------------------------------------------

if (-not $NoBrowser) {

    Write-Step "Locating Chrome"

    $chromeCandidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Chromium\Application\chrome.exe",
        "$env:LocalAppData\Chromium\Application\chrome.exe"
    )

    $chromePath = $chromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $chromePath) {
        Write-Fail "Chrome not found. Install Google Chrome or set the path manually."
        exit 1
    }

    Write-Ok "Found: $chromePath"

    # Wait for web dashboard before opening browser
    Write-Step "Waiting for web dashboard to become ready"

    $webPort    = if ($Dev) { <DEV_PORT> } else { <PROD_PORT> }
    $webLogSvc  = if ($Dev) { '<WEB_DEV_SERVICE>' } else { '<WEB_PROD_SERVICE>' }
    $webTimeout = if ($Dev) { 120 } else { 60 }   # dev server installs deps first
    $webReady   = $false
    $webDeadline = (Get-Date).AddSeconds($webTimeout)

    Write-Host "    Polling http://127.0.0.1:$webPort" -NoNewline

    while ((Get-Date) -lt $webDeadline) {
        try {
            $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$webPort" `
                        -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($resp -and $resp.StatusCode -eq 200) {
                $webReady = $true
                Write-Host " ready" -ForegroundColor Green
                break
            }
        } catch { }
        Write-Host '.' -NoNewline
        Start-Sleep -Seconds 2
    }

    if (-not $webReady) {
        Write-Host ""
        Write-Warn "Web dashboard did not respond within ${webTimeout} s — it may still be starting."
        Write-Host "    Check logs with: $ComposeCmd logs -f $webLogSvc" -ForegroundColor Yellow
    }

    # Launch Chrome with isolated profile + loaded extension
    $webUrl = if ($Dev) { 'http://localhost:<DEV_PORT>' } else { 'http://localhost:<PROD_PORT>' }

    if (-not (Test-Path $ChromeProfile)) {
        New-Item -ItemType Directory -Path $ChromeProfile | Out-Null
    }

    $chromeArgs = @(
        "--user-data-dir=`"$ChromeProfile`""
        "--load-extension=`"$DistDir`""
        "--no-first-run"
        "--no-default-browser-check"
        $webUrl
        # Add any additional URLs to open (e.g. API docs):
        # "<API_DOCS_URL>"
    )

    Write-Host "    Profile  : $ChromeProfile"
    Write-Host "    Extension: $DistDir"
    Write-Host "    Opening  : $webUrl"

    Start-Process -FilePath $chromePath -ArgumentList $chromeArgs
    Write-Ok "Chrome launched"
    Write-Warn "Extension ID differs from production — expected for unpacked extensions."
}

# ---------------------------------------------------------------------------
# [NATIVE PROCESS VARIANT] Use this block INSTEAD of the Docker Compose blocks
# above when the project has no docker-compose.yml. Start each service as a
# background PowerShell job, then run the UI in the foreground.
#
# Only include if the project does not use Docker Compose.
# ---------------------------------------------------------------------------
#
# Write-Step "Starting infrastructure"
# # e.g. start Postgres if not managed by Docker
# Start-Job -Name "db" -ScriptBlock { pg_ctl start -D "$env:PGDATA" }
#
# Write-Step "Starting API"
# $apiJob = Start-Job -Name "api" -ScriptBlock {
#     Set-Location "<REPO_ROOT>\<API_DIR>"
#     uv run uvicorn <module>:app --reload --port <API_PORT>
# }
#
# Write-Step "Starting web (foreground)"
# Set-Location "<REPO_ROOT>\<WEB_DIR>"
# npm run dev   # foreground — script blocks here until user Ctrl-C

# ---------------------------------------------------------------------------
# 7. Summary
# Always include. Print every service URL and the most useful operational
# commands so the developer can orient quickly after the script completes.
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  <PROJECT_NAME> is running" -ForegroundColor Green
if ($Dev) { Write-Host "  (hot-reload dev mode)" -ForegroundColor Magenta }
Write-Host "===========================================" -ForegroundColor Cyan

# <SERVICE_URLS>: one line per exposed endpoint
if ($Dev) {
    Write-Host "  Web:    http://localhost:<DEV_PORT>  (Vite HMR)"
} else {
    Write-Host "  Web:    http://localhost:<PROD_PORT>"
}
Write-Host "  API:    http://localhost:<API_PORT>"
Write-Host "  Docs:   http://localhost:<API_PORT>/docs"   # remove if no API docs

Write-Host ""
Write-Host "  Useful commands:"
if ($Dev) {
    Write-Host "    $ComposeCmd logs -f <WEB_DEV_SERVICE>   # stream dev server logs"
} else {
    Write-Host "    $ComposeCmd logs -f <WEB_PROD_SERVICE>  # stream web logs"
}
Write-Host "    $ComposeCmd logs -f <API_SERVICE>         # stream API logs"
Write-Host "    $ComposeCmd ps                            # service status"
Write-Host "    $ComposeCmd down                          # stop everything"
Write-Host ""
```

### Checklist before saving the generated script

- [ ] All `<PLACEHOLDER>` tokens replaced with real values
- [ ] Extension section removed if no `extension/` directory exists
- [ ] `Test-SetupRequired` secret key list matches actual `.env.example` keys
- [ ] `Test-ImageStale` source dirs match the project's Dockerfile `COPY` paths
- [ ] API health URL confirmed to return 200 when healthy
- [ ] Web port numbers correct for dev and prod modes
- [ ] Summary block lists all exposed service URLs
- [ ] Script saved to `scripts/Start-App.ps1` and tested with a dry run

### When to use native processes instead of Docker Compose

If `docker-compose.yml` does not exist in the project root, replace the Docker Compose blocks with native process management (see the commented `NATIVE PROCESS VARIANT` section in the template above). Use `Start-Job` for background services and run the UI in the foreground so `Ctrl-C` is the natural stop mechanism.

---

## Cache file — purpose and structure

### Location

Always `docs/framework/start-app.md` relative to the repo root. The `docs/framework/` directory is the canonical home for framework-level operational docs in this workstation; placing the cache there keeps it alongside other runbook-style artefacts rather than cluttering repo root. Create the directory if it does not exist.

### Purpose

The cache exists to **eliminate redundant discovery inference on every run**. Steps 1–2 are expensive — filesystem scans, manifest parsing, and disambiguation dialogs — and their answers are stable until the solution itself changes. By writing those answers to a durable, human-readable file, every subsequent run becomes a two-step flow: read the cache, execute the command.

It is also a communication artefact. Because it is plain markdown checked into the repo, it travels with the project: a new contributor, a CI script, or a future invocation of this skill on a different machine all see the same confirmed startup intelligence without re-running the investigation.

### Structure

The file is a single markdown document with YAML frontmatter for structured data plus named prose sections. Every cache must include these sections in this order:

| Section | Purpose |
|---|---|
| YAML frontmatter | Structured metadata — `schema`, `generated`, `generated-by`, `project`, `project-root`, `stack` (list), `invalidation-watches` (list of repo-relative paths whose mtime invalidates the cache). |
| **How to use this file** | One paragraph telling the next reader (human or skill) how to consume, refresh, or update the cache. Keep this stable across regenerations so documentation links don't rot. |
| **Default startup command** | The single authoritative command used when no variant is requested. Fenced code block, one command. |
| **Startup variants** | Table of named variants (`dev`, `prod`, `backend-only`, `rebuild`, …). Columns: variant label → command → when to use. Omit the table if no variants exist. |
| **Services** | Table of services discovered during investigation. Columns: service name → role (`infra` / `api` / `web` / `worker`) → URL → port → health endpoint. |
| **Environment** | `.env` file location, required secret keys, setup script (if any). |
| **Runtime dependencies** | External tools that must be installed or running (Docker Desktop, Node.js 20+, PowerShell 7+, specific DB clients, etc.). |
| **Success signals** | Output patterns that confirm a successful start for *this* solution — these are more specific than the generic list in Step 3 of this skill. |
| **Known failure recoveries** | Table of errors previously seen for this solution and the fix that worked. Grows over time as Mode 1 / Mode 3 runs encounter and resolve new failures. |
| **Notes** | Free-form prose for quirks, first-run timing, caveats that don't fit the structured sections. |
| **Change log** | Dated table of cache writes and the reason. Every successful run appends a row; keep the most recent 20 rows and drop older ones to prevent unbounded growth. |

### The `invalidation-watches` field

This is the field that determines whether Mode 1 is safe. List every repo-relative path whose change could invalidate any answer in the cache. A correct watch list typically includes:

- The startup script itself (e.g. `scripts/Start-App.ps1`)
- `docker-compose.yml` / `docker-compose.yaml` (services, ports, profiles)
- Every `package.json` that contributes a service (workspace-style monorepos have several)
- `pyproject.toml`, `requirements.txt`, `uv.lock`, `poetry.lock` (Python stacks)
- `.env.example` (required-secret list)
- Any `Makefile` or `Procfile` whose targets are referenced in the cache
- The `scripts/` directory *contents* if the cache's *Default startup command* delegates to one

Err on the side of including too many paths rather than too few — a spurious Mode 3 trigger costs one extra investigation, but a missed invalidation makes Mode 1 execute a wrong command.

### Cache template

When generating or updating the cache, use this structure exactly. Replace every `<placeholder>` with a real value for the current solution; remove rows and sections that do not apply.

````markdown
---
schema: start-app/v1
generated: <ISO-8601 UTC timestamp, e.g. 2026-04-21T14:12:00Z>
generated-by: start-app skill
project: <repo name>
project-root: <absolute path to repo root>
stack:
  - <docker-compose | node | python | dotnet | go | rust | rails | java | php | ...>
invalidation-watches:
  - <repo-relative path>
  - <repo-relative path>
---

# Start-App Intelligence Cache

Generated by the `start-app` skill. This file records everything needed to
launch this solution without re-investigating on every run.

## How to use this file

- **Fast path**: If this file is fresh (no watched path newer than `generated`),
  run the *Default startup command* and skip discovery.
- **Refresh**: Delete this file or invoke `/start-app --refresh` to force a
  full re-investigation.
- **Update**: Invoke `/start-app --update` (or tell the skill "my solution
  changed") to diff against the current repo and rewrite.

## Default startup command

```
<single shell command, run from repo root>
```

## Startup variants

| Variant | Command | When to use |
|---|---|---|
| <name> | `<command>` | <one-line description> |

## Services

| Service | Role | URL | Port | Health endpoint |
|---|---|---|---|---|
| <name> | <infra / api / web / worker> | <url> | <port> | <path or "docker healthcheck"> |

## Environment

- `.env` file: `<path>`
- Required secrets: `<KEY_1>`, `<KEY_2>`, ...
- Setup script: `<path or "none">`

## Runtime dependencies

- <tool> <required version / state>
- ...

## Success signals

- <output pattern observed on a successful start>
- ...

## Known failure recoveries

| Error | Fix |
|---|---|
| <pattern> | <resolution that worked> |

## Notes

<free-form prose — first-run timing, quirks, ordering caveats>

## Change log

| Date | Change | Reason |
|---|---|---|
| <YYYY-MM-DD> | <short description> | <what prompted the change> |
````

### Writing checklist

Before saving a generated or updated cache, verify:

- [ ] `generated` is a UTC ISO-8601 timestamp, not a local-time or human-readable string
- [ ] `invalidation-watches` includes every file whose change could alter any answer above (startup script, compose file, package manifests, `.env.example`)
- [ ] *Default startup command* is the exact command the skill would run — no ambiguity, no commentary
- [ ] Every row in *Services* lists a URL/port that was actually observed responding during Step 3
- [ ] *Known failure recoveries* has no duplicate rows carried over from prior runs
- [ ] *Change log* has a new row describing the current write
