<#
.SYNOPSIS
Rate-limit-aware HTTP fetch helper. Drop-in for any HTTP-fetching phase.

.DESCRIPTION
Returns a typed status hashtable so the caller can switch cleanly:

  { status = 'ok';        content; status_code; headers; url }
  { status = 'throttle';  retry_after; url }                              -- 429 with Retry-After parsed
  { status = 'not_found'; url }                                            -- 404
  { status = 'error';     message; url; status_code? }                     -- timeout / 5xx / network

Uses Invoke-WebRequest -SkipHttpErrorCheck (PowerShell 7+) so the response
is always available without try/catch noise on non-2xx codes.

.EXAMPLE
$r = Invoke-RateLimitedFetch -Url $url -Token $env:GITHUB_TOKEN
switch ($r.status) {
    'ok'        { Set-Content -Path $out -Value $r.content; $row.fetched = 'true' }
    'throttle'  { Start-Sleep -Seconds $r.retry_after; $throttleStreak++ }
    'not_found' { Write-LogEvent -Status 'warn' -Message "404 on $url" }
    default     { Write-LogEvent -Status 'warn' -Message "fetch failed: $($r.message)" }
}
#>

function Invoke-RateLimitedFetch {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [string]$Token = '',
        [string]$UserAgent = 'csv-pipeline/1.0',
        [int]$TimeoutSec = 15,
        [hashtable]$ExtraHeaders = @{}
    )

    $headers = @{ 'User-Agent' = $UserAgent }
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }
    foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }

    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $TimeoutSec `
                  -SkipHttpErrorCheck -ErrorAction Stop
    } catch {
        return @{ status='error'; message=$_.Exception.Message; url=$Url }
    }

    $code = [int]$resp.StatusCode
    if ($code -eq 200) {
        return @{
            status      = 'ok'
            content     = $resp.Content
            status_code = $code
            headers     = $resp.Headers
            url         = $Url
        }
    }
    if ($code -eq 429) {
        $retry = 60
        try {
            $h = $resp.Headers['Retry-After']
            if ($h) {
                $v = if ($h -is [array]) { $h[0] } else { $h }
                if ($v -match '^\d+$') { $retry = [int]$v }
            }
        } catch { }
        return @{ status='throttle'; retry_after=$retry; url=$Url }
    }
    if ($code -eq 404) { return @{ status='not_found'; url=$Url } }
    return @{ status='error'; message="HTTP $code"; status_code=$code; url=$Url }
}

# === Caller-side loop pattern with circuit breaker ===

function Invoke-FetchLoop {
    <#
    .SYNOPSIS
    Reference loop that pairs Invoke-RateLimitedFetch with a circuit breaker
    and inter-request delay. Adapt to your CSV row shape.
    #>
    param(
        [Parameter(Mandatory)] [object[]]$Rows,
        [Parameter(Mandatory)] [scriptblock]$UrlSelector,    # { param($row) $row.url }
        [Parameter(Mandatory)] [scriptblock]$OnSuccess,      # { param($row, $result) ... }
        [scriptblock]$OnNotFound = { param($row, $result) },
        [scriptblock]$OnError    = { param($row, $result) },
        [scriptblock]$Save       = { },
        [int]$RequestDelayMs    = 250,
        [int]$MaxThrottleStreak = 5,
        [string]$Token          = ''
    )
    $streak = 0
    foreach ($row in $Rows) {
        $url = & $UrlSelector $row
        $result = Invoke-RateLimitedFetch -Url $url -Token $Token
        switch ($result.status) {
            'ok'        { & $OnSuccess  $row $result; $streak = 0; & $Save }
            'throttle'  {
                $streak++
                Start-Sleep -Seconds $result.retry_after
                if ($streak -ge $MaxThrottleStreak) {
                    Write-Warning "Hit $MaxThrottleStreak consecutive throttles; aborting loop"
                    & $Save
                    return
                }
            }
            'not_found' { & $OnNotFound $row $result; $streak = 0 }
            default     { & $OnError    $row $result; $streak = 0 }
        }
        if ($RequestDelayMs -gt 0) { Start-Sleep -Milliseconds $RequestDelayMs }
    }
}
