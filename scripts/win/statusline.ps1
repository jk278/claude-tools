# Statusline script - model, directory, git branch, progress, API calls, tokens, time
#
# EXECUTION: Runs ~300ms during token output only, NOT on terminal resize.
#

# ===== Initialization =====
$ESC = [char]27
$showCost = $true  # Set to $false to show tokens instead
$inputJson = $input | Out-String | ConvertFrom-Json
$model = $inputJson.model.display_name
$currentDir = Split-Path -Leaf $inputJson.workspace.current_dir

# ===== Git Branch =====
# Get git branch if available
$gitBranch = ""
if (Test-Path .git) {
    try {
        $headContent = Get-Content .git/HEAD -ErrorAction Stop
        if ($headContent -match "ref: refs/heads/(.*)") {
            $gitBranch = " · $ESC[38;5;97m⎇ " + $matches[1] + "$ESC[0m"
        }
    } catch {}
}

# ===== Cache & Session =====
# Cache file: percent|session_id
$cacheFile = "$env:TEMP\claude_statusline_cache.txt"
$cachedData = if (Test-Path $cacheFile) { Get-Content $cacheFile } else { "" }
$cachedPercent, $cachedSessionId = $cachedData -split "\|"

# Session mismatch = new session, reset
$currentSessionId = $inputJson.session_id.Substring(0, 8)
if ($cachedSessionId -ne $currentSessionId) {
    $cachedPercent = "0"
}

# ===== Data Preparation =====
# Context usage - use cache to prevent showing 0% when current_usage temporarily returns 0
$usage = $inputJson.context_window.current_usage
$displayPercent = $cachedPercent

if ($usage -and $usage.PSObject.Properties.Count -gt 0) {
    $currentTokens = $usage.input_tokens + $usage.cache_creation_input_tokens + $usage.cache_read_input_tokens
    $contextSize = $inputJson.context_window.context_window_size
    if ($contextSize -gt 0 -and $currentTokens -gt 0) {
        $percent = [math]::Round(($currentTokens * 100) / $contextSize, 0)
        $displayPercent = $percent
        # Update cache: percent|session_id
        "$percent|$currentSessionId" | Out-File $cacheFile -Encoding UTF8
    }
}

# Count API calls from transcript (no cache needed, always recalculate)
$currentCalls = "0"
$transcriptPath = $inputJson.transcript_path
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    $count = 0
    Get-Content $transcriptPath | ForEach-Object {
        $data = $_ | ConvertFrom-Json
        if ($data.message.usage -and !$data.isSidechain -and !$data.isApiErrorMessage) {
            $count++
        }
    }
    $currentCalls = $count.ToString()
}

# Token usage (input↑ output↓, auto unit k/M) or Cost
$inTokens = $inputJson.context_window.total_input_tokens
$outTokens = $inputJson.context_window.total_output_tokens
$cost = $inputJson.cost.total_cost_usd

# Duration formatting (always in hours, 1 decimal)
$duration = $inputJson.cost.total_duration_ms / 1000
$hours = [math]::Round($duration / 3600, 1)
$timeStr = "$ESC[90m${hours}h$ESC[0m"

# ===== Display Building =====
$barSize = 10
$filled = [math]::Round($displayPercent / (100 / $barSize))
$empty = $barSize - $filled
$bar = ("■" * $filled) + ("□" * $empty)
$percentColor = if ($displayPercent -gt 80) { "$ESC[33m" } else { "$ESC[32m" }
$progress = $percentColor + $bar + " " + $displayPercent + "%$ESC[0m"

$calls = "$ESC[38;5;208m⬡ ${currentCalls}c$ESC[0m"

if ($showCost) {
    $costStr = "$ESC[38;5;136m$" + [math]::Round($cost, 2) + "$ESC[0m"
}
else {
    $inFmt = if ($inTokens -ge 1MB) { [math]::Round($inTokens / 1MB, 1).ToString() + "M" } else { [math]::Round($inTokens / 1KB, 0).ToString() + "k" }
    $outFmt = if ($outTokens -ge 1MB) { [math]::Round($outTokens / 1MB, 1).ToString() + "M" } else { [math]::Round($outTokens / 1KB, 0).ToString() + "k" }
    $costStr = "$ESC[90m↑$ESC[0m$ESC[38;5;136m$inFmt$ESC[0m $ESC[90m↓$ESC[0m$ESC[38;5;136m$outFmt$ESC[0m"
}

# ===== Zenmux Usage =====
$zenmuxSegment = ""
$pluginRoot = (Get-Item "$PSScriptRoot\..\.." ).FullName
$usagesFile = Join-Path $pluginRoot "usages.json"

if (Test-Path $usagesFile) {
    $envFile = Join-Path $pluginRoot ".env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match "^([^#][^=]*)=(.*)$") {
                [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
            }
        }
    }

    $enabledProviders = ([System.Environment]::GetEnvironmentVariable("ENABLED_PROVIDER") -split ",") | ForEach-Object { $_.Trim() }
    if ($enabledProviders -contains "zenmux") {
        $usages = Get-Content $usagesFile | ConvertFrom-Json
        $sessionId  = [System.Environment]::GetEnvironmentVariable($usages.zenmux.sessionIdEnv)
        $sessionSig = [System.Environment]::GetEnvironmentVariable($usages.zenmux.sessionSigEnv)

        if ($sessionId -and $sessionSig) {
            $zCacheFile = "$env:TEMP\zenmux_usage_cache.txt"
            $zNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $weekRate = $null; $hour5Rate = $null

            if (Test-Path $zCacheFile) {
                $zParts = (Get-Content $zCacheFile) -split "\|"
                if ($zParts.Count -eq 3 -and ($zNow - [long]$zParts[2]) -lt 60) {
                    $weekRate = [double]$zParts[0]; $hour5Rate = [double]$zParts[1]
                }
            }

            if ($null -eq $weekRate) {
                try {
                    $resp = Invoke-RestMethod `
                        -Uri "https://zenmux.ai/api/subscription/get_current_usage" `
                        -Headers @{ "Cookie" = "sessionId=$sessionId; sessionId.sig=$sessionSig" } `
                        -TimeoutSec 3
                    if ($resp.success) {
                        $weekRate  = ($resp.data | Where-Object { $_.periodType -eq "week"   }).usedRate
                        $hour5Rate = ($resp.data | Where-Object { $_.periodType -eq "hour_5" }).usedRate
                        "$weekRate|$hour5Rate|$zNow" | Out-File $zCacheFile -Encoding UTF8
                    }
                } catch {}
            }

            if ($null -ne $weekRate -and $null -ne $hour5Rate) {
                function Get-ZUsageColor($r) {
                    $p = $r * 100
                    if ($p -ge 90) { "$ESC[31m" } elseif ($p -ge 70) { "$ESC[33m" } else { "$ESC[32m" }
                }
                $wPct  = [math]::Round($weekRate  * 100)
                $h5Pct = [math]::Round($hour5Rate * 100)
                $wCol  = Get-ZUsageColor $weekRate
                $h5Col = Get-ZUsageColor $hour5Rate
                $zenmuxSegment = " · Z: ${wCol}${wPct}%$ESC[0m ${h5Col}${h5Pct}%$ESC[0m"
            }
        }
    }
}

# ===== Output =====
Write-Output "$ESC[36m⚡$model$ESC[0m · $ESC[34m□ $currentDir$ESC[0m$gitBranch · $progress · $calls · $costStr · ⧖ $timeStr$zenmuxSegment"
