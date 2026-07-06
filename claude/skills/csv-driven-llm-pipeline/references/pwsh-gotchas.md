# PowerShell Gotchas

The pitfalls that cost hours when building these pipelines. Each one is a real bug that bit during the github-awesome rebuild.

## 1. `[string]` collapses comma-separated parameters

```powershell
# WRONG
param([string]$Phase = 'all')
# Caller: -Phase readme,analyze,score
# $Phase becomes 'readme analyze score' (single string, space-joined)
# $Phase -split ',\s*' returns @('readme analyze score') — one element

# RIGHT
param([string[]]$Phase = @('all'))
# $Phase becomes @('readme', 'analyze', 'score') — three elements
```

If you need to support both `-Phase a,b` and `-Phase 'a,b'` (single string with commas), normalize:

```powershell
$phaseList = @($Phase | ForEach-Object { $_ -split ',\s*' } |
    ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
```

## 2. `${var}:` vs `$var:`

```powershell
# WRONG — PS parses $url: as scope/drive prefix
"Failed for $url: $_"
# Parser error: "Variable reference is not valid. ':' was not followed by a valid variable name character."

# RIGHT — wrap with ${}
"Failed for ${url}: $_"
```

Comes up constantly in error message strings. Same applies to `$var.` followed by something parser-significant — use `${var}` to disambiguate.

## 3. Reserved automatic variables shadow your locals

```powershell
$profile = Get-Content 'profile.md'   # WRONG — $profile is the path to your PS profile script
$matches = @{}                          # WRONG — $matches is set by -match
$_ = $row                               # WRONG — $_ is the pipeline current item
```

Rename to `$userProfile`, `$matchedItems`, `$current`. PowerShell will silently accept the assignment but downstream code that expects the automatic variable breaks.

Full reserved list: `$_, $args, $error, $foreach, $home, $host, $input, $matches, $myinvocation, $null, $profile, $pshome, $pwd, $true, $false`.

## 4. Triple backticks in here-strings

```powershell
# WRONG — backticks are PS escape characters
$prompt = "URL: $url`nREADME:`n```n$readme`n```"
# Parser error: "The string is missing the terminator"

# RIGHT — assign the fence to a variable first
$fence = '```'
$prompt = "URL: $url`nREADME:`n$fence`n$readme`n$fence"
```

Or use a single-quoted here-string + concatenation:

```powershell
$prompt = @'
URL:
'@ + $url + @'

README:
```
'@ + $readme + @'
```
'@
```

## 5. Use `-SkipHttpErrorCheck` instead of try/catch around Invoke-WebRequest

PowerShell 7+ added `-SkipHttpErrorCheck` which makes `Invoke-WebRequest` return the response on non-2xx status codes instead of throwing. This makes 429-handling much cleaner:

```powershell
# OLD — try/catch dance, response object access via exception is brittle
try {
    $resp = Invoke-WebRequest -Uri $url -ErrorAction Stop
} catch {
    $code = [int]$_.Exception.Response.StatusCode
    # Headers access varies between PS5 and PS7+ exception types
}

# NEW — response always returned
$resp = Invoke-WebRequest -Uri $url -SkipHttpErrorCheck
$code = [int]$resp.StatusCode
$retry = $resp.Headers['Retry-After']
```

## 6. `[PSCustomObject][ordered]@{}` for predictable column order

```powershell
# WRONG — hashtables don't preserve order
$row = [PSCustomObject]@{
    a = 1; b = 2; c = 3
}
# When piped to Export-Csv, columns may emit in any order

# RIGHT — [ordered]@{} guarantees insertion order
$row = [PSCustomObject]([ordered]@{
    a = 1; b = 2; c = 3
})
```

Important when round-tripping CSVs — Import-Csv → mutate → Export-Csv should produce a stable diff. Without `[ordered]`, columns can shuffle between runs.

## 7. `Save the CSV inside the loop, not after`

```powershell
# WRONG — crash mid-loop loses all progress
foreach ($row in $rows) {
    $row.done = 'true'
}
$rows | Export-Csv $csv -NoTypeInformation

# RIGHT — per-row write
foreach ($row in $rows) {
    $row.done = 'true'
    $rows | Export-Csv $csv -NoTypeInformation -Encoding utf8
}
```

The "wasteful" full re-write every row is fine — even at 100k rows, it's microseconds compared to the actual per-row work (HTTP fetch, LLM call). Resume-resilience is worth far more than the I/O.

## 8. Property name with space needs quoting in dot notation

```powershell
# WRONG
$row.youAttributedStringHost 2

# RIGHT — quote the whole property name
$row.'ytAttributedStringHost 2'
```

Scrape-style CSVs often have these. Use `Import-Csv` and dot-quote the property name.

## 9. `$LASTEXITCODE` after native commands, not PS commands

```powershell
& yt-dlp --dump-single-json $url
if ($LASTEXITCODE -ne 0) { ... }    # works for native
```

```powershell
Invoke-RestMethod -Uri $url
if ($LASTEXITCODE -ne 0) { ... }    # WRONG — $LASTEXITCODE doesn't update for PS cmdlets
```

For PowerShell cmdlets, use try/catch or `$?` (boolean indicating last command succeeded).

## 10. UTF-8 BOM vs no-BOM

`Set-Content -Encoding utf8` writes UTF-8 with BOM in PowerShell 5.1, no BOM in 7+. For consistency:

```powershell
# Always no-BOM (works in 7+; 5.1 needs explicit conversion)
Set-Content -Path $p -Value $content -Encoding utf8 -NoNewline
```

If targeting both, write `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))` — the `$false` argument means no BOM.

## 11. `Get-ChildItem -Filter` is faster than `-Include`

```powershell
# Slow on large directories
Get-ChildItem -Recurse -Include '*.md'

# Fast
Get-ChildItem -Recurse -Filter '*.md'
```

`-Filter` is passed to the OS; `-Include` filters in PowerShell after enumeration. With 2000+ files, the difference is multiple seconds.
