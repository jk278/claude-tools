# Statusline script - model, directory, git branch, progress, API calls, tokens, time
#
# EXECUTION: Runs ~300ms during token output only, NOT on terminal resize.
#

# ===== Initialization =====
$ESC = [char]27
$showCost = $true  # Set to $false to show tokens instead
# Nerd Font icons
$iBolt   = [char]0xF0E7  # nf-fa-bolt
$iFolder = [char]0xF07B  # nf-fa-folder
$iBranch = [char]0xE0A0  # nf-pl-branch
$iCube   = [char]0xF292  # nf-fa-hashtag
$iClock  = [char]0xF017  # nf-fa-clock_o
$iZenmux   = [char]0xF080  # nf-fa-bar-chart
$iRefresh  = [char]0xF021  # nf-fa-refresh
$iUsd      = [char]0xF155  # nf-fa-usd
$iUp       = [char]0xF093  # nf-fa-upload
$iDown     = [char]0xF019  # nf-fa-download
$iCalendar = [char]0xF073  # nf-fa-calendar
$iCloud    = [char]0xF0C2  # nf-fa-cloud
$inputJson = $input | Out-String | ConvertFrom-Json
$model = $inputJson.model.display_name
$currentDir = Split-Path -Leaf $inputJson.workspace.current_dir

# ===== Git Branch =====
$gitBranch = ""
if (Test-Path .git) {
    try {
        $headContent = Get-Content .git/HEAD -ErrorAction Stop
        if ($headContent -match "ref: refs/heads/(.*)") {
            $gitBranch = " · $ESC[38;5;97m$iBranch $($matches[1])$ESC[0m"
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

# Duration formatting (xhx)
$duration = $inputJson.cost.total_duration_ms / 1000
$dInt   = [math]::Floor($duration / 3600)
$dTenth = [math]::Floor(($duration / 3600 - $dInt) * 10)
$timeStr = "$ESC[90m${dInt}h$(if ($dTenth) { $dTenth })$ESC[0m"

# ===== Display Building =====
$barSize = 10
$filled = [math]::Round($displayPercent / (100 / $barSize))
$empty = $barSize - $filled
$bar = ([char]0x2588).ToString() * $filled + ([char]0x2591).ToString() * $empty
$percentColor = if ($displayPercent -gt 80) { "$ESC[33m" } else { "$ESC[32m" }
$progress = $percentColor + $bar + " " + $displayPercent + "%$ESC[0m"

$calls = "$ESC[38;5;208m$iCube ${currentCalls}c$ESC[0m"

if ($showCost) {
    $costStr = "$ESC[38;5;136m$iUsd " + [math]::Round($cost, 2) + "$ESC[0m"
}
else {
    $inFmt = if ($inTokens -ge 1MB) { [math]::Round($inTokens / 1MB, 1).ToString() + "M" } else { [math]::Round($inTokens / 1KB, 0).ToString() + "k" }
    $outFmt = if ($outTokens -ge 1MB) { [math]::Round($outTokens / 1MB, 1).ToString() + "M" } else { [math]::Round($outTokens / 1KB, 0).ToString() + "k" }
    $costStr = "$ESC[90m$iUp $ESC[0m$ESC[38;5;136m$inFmt$ESC[0m $ESC[90m$iDown $ESC[0m$ESC[38;5;136m$outFmt$ESC[0m"
}

# ===== Zenmux Usage =====
$zenmuxSegment = ""
$pluginRoot = (Get-Item "$PSScriptRoot\..\.." ).FullName

# Load .env once (shared by all provider blocks)
$envFile = Join-Path $pluginRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^#][^=]*)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
        }
    }
}

$usagesFile = Join-Path $pluginRoot "usages.json"

if (Test-Path $usagesFile) {
    $enabledProviders = ([System.Environment]::GetEnvironmentVariable("ENABLED_PROVIDER") -split ",") | ForEach-Object { $_.Trim() }
    if ($enabledProviders -contains "zenmux") {
        $usages = Get-Content $usagesFile | ConvertFrom-Json
        $sessionId  = [System.Environment]::GetEnvironmentVariable($usages.zenmux.sessionIdEnv)
        $sessionSig = [System.Environment]::GetEnvironmentVariable($usages.zenmux.sessionSigEnv)

        if (-not ($sessionId -and $sessionSig)) {
            $zenmuxSegment = " · $ESC[31m$iZenmux !cfg$ESC[0m"
        } else {
            $zCacheFile = "$env:TEMP\claude_zenmux_usage_cache.txt"
            $zNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $weekRate = $null; $hour5Rate = $null
            $weekEnd = $null; $h5End = $null

            if (Test-Path $zCacheFile) {
                $zParts = (Get-Content $zCacheFile) -split "\|"
                if ($zParts.Count -eq 5 -and ($zNow - [long]$zParts[4]) -lt 60) {
                    $hour5Rate = [double]$zParts[0]; $h5End  = $zParts[1]
                    $weekRate  = [double]$zParts[2]; $weekEnd = $zParts[3]
                }
            }

            if ($null -eq $weekRate) {
                try {
                    $resp = Invoke-RestMethod `
                        -Uri "https://zenmux.ai/api/subscription/get_current_usage" `
                        -Headers @{ "Cookie" = "sessionId=$sessionId; sessionId.sig=$sessionSig" } `
                        -TimeoutSec 3
                    if ($resp.success) {
                        $wData  = $resp.data | Where-Object { $_.periodType -eq "week" }
                        $h5Data = $resp.data | Where-Object { $_.periodType -eq "hour_5" }
                        $weekRate  = $wData.usedRate;  $weekEnd  = $wData.cycleEndTime
                        $hour5Rate = $h5Data.usedRate; $h5End    = $h5Data.cycleEndTime
                        "$hour5Rate|$h5End|$weekRate|$weekEnd|$zNow" | Out-File $zCacheFile -Encoding UTF8
                    } else {
                        $zenmuxSegment = " · $ESC[31m$iZenmux !auth$ESC[0m"
                    }
                } catch {
                    $zenmuxSegment = " · $ESC[90m$iZenmux …$ESC[0m"
                }
            }

            if ($null -ne $weekRate -and $null -ne $hour5Rate) {
                function Get-ZUsageColor($r) {
                    $p = $r * 100
                    if ($p -ge 90) { "$ESC[31m" } elseif ($p -ge 70) { "$ESC[33m" } else { "$ESC[32m" }
                }
                function Format-ZReset($endStr) {
                    try {
                        $left = [datetime]::Parse($endStr) - [datetime]::UtcNow
                        if ($left.TotalSeconds -le 0) { return "" }
                        $hInt   = [math]::Floor($left.TotalHours)
                        $hTenth = [math]::Floor(($left.TotalHours - $hInt) * 10)
                        return "$iRefresh ${hInt}h$(if ($hTenth) { $hTenth })"
                    } catch { return "" }
                }
                $wPct  = [math]::Round($weekRate  * 100)
                $h5Pct = [math]::Round($hour5Rate * 100)
                $wCol  = Get-ZUsageColor $weekRate
                $h5Col = Get-ZUsageColor $hour5Rate
                $h5Reset = if ($h5End) { " $ESC[90m$(Format-ZReset $h5End)$ESC[0m" } else { "" }
                $wReset  = if ($weekEnd) { " $ESC[90m$(Format-ZReset $weekEnd)$ESC[0m" } else { "" }
                $zenmuxSegment = " · $iZenmux ${h5Col}H${h5Pct}%$ESC[0m$h5Reset / ${wCol}W${wPct}%$ESC[0m$wReset"
            }
        }
    }
}

# ===== Weather =====
$weatherSegment = ""
$weatherFile = Join-Path $pluginRoot "weather.json"

if (Test-Path $weatherFile) {
    $weatherEnabled = [System.Environment]::GetEnvironmentVariable("QWEATHER_ENABLED")
    if ($weatherEnabled -eq "true") {
        $wCfg     = Get-Content $weatherFile | ConvertFrom-Json
        $wHost    = [System.Environment]::GetEnvironmentVariable($wCfg.hostEnv)
        $wLoc     = [System.Environment]::GetEnvironmentVariable($wCfg.locationEnv)
        $wKey     = [System.Environment]::GetEnvironmentVariable($wCfg.keyEnv)

        if (-not ($wHost -and $wLoc -and $wKey)) {
            $weatherSegment = " · $ESC[31m${iCloud} !cfg$ESC[0m"
        } else {
            $wCacheFile = "$env:TEMP\claude_weather_cache.txt"
            $wNow       = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $wTemp = $null; $wText = $null; $wMax = $null; $wMin = $null

            if (Test-Path $wCacheFile) {
                $wParts = (Get-Content $wCacheFile -Raw).Trim() -split '\|', 5
                if ($wParts.Count -eq 5 -and ($wNow - [long]$wParts[3]) -lt 600) {
                    $wTemp = $wParts[0]; $wMax = $wParts[1]; $wMin = $wParts[2]; $wText = $wParts[4]
                }
            }

            if ($null -eq $wTemp) {
                try {
                    $nowJob = $null; $fcJob = $null
                    $wHeaders = @{ "X-QW-Api-Key" = $wKey }
                    $nowJob = Start-Job {
                        param($h, $l, $hdr)
                        Invoke-RestMethod -Uri "$h/v7/weather/now?location=$l&lang=en" -Headers $hdr -TimeoutSec 3
                    } -ArgumentList $wHost, $wLoc, $wHeaders
                    $fcJob = Start-Job {
                        param($h, $l, $hdr)
                        Invoke-RestMethod -Uri "$h/v7/weather/3d?location=$l&lang=en" -Headers $hdr -TimeoutSec 3
                    } -ArgumentList $wHost, $wLoc, $wHeaders

                    $null = Wait-Job $nowJob, $fcJob -Timeout 4
                    $nowResp = Receive-Job $nowJob -ErrorAction SilentlyContinue
                    $fcResp  = Receive-Job $fcJob  -ErrorAction SilentlyContinue

                    if ($nowResp.code -eq "200" -and $fcResp.code -eq "200") {
                        $wTemp = $nowResp.now.temp
                        $wText = $nowResp.now.text
                        $wMax  = $fcResp.daily[0].tempMax
                        $wMin  = $fcResp.daily[0].tempMin
                        "$wTemp|$wMax|$wMin|$wNow|$wText" | Out-File $wCacheFile -Encoding UTF8 -NoNewline
                    } elseif ($nowResp -or $fcResp) {
                        $weatherSegment = " · $ESC[31m${iCloud} !api$ESC[0m"
                    } else {
                        $weatherSegment = " · $ESC[90m${iCloud} …$ESC[0m"
                    }
                } catch {
                    $weatherSegment = " · $ESC[90m${iCloud} …$ESC[0m"
                } finally {
                    if ($nowJob) { Remove-Job $nowJob -Force -ErrorAction SilentlyContinue }
                    if ($fcJob)  { Remove-Job $fcJob  -Force -ErrorAction SilentlyContinue }
                }
            }

            if ($null -ne $wTemp) {
                $weatherSegment = " · ${iCloud} $ESC[36m${wTemp}°$ESC[0m $wText $ESC[90m${wMin}~${wMax}°$ESC[0m"
            }
        }
    }
}

# ===== Output =====
$nowStr = "$ESC[90m$iCalendar $ESC[0m" + (Get-Date -Format "MM-dd HH:mm")
Write-Output "$ESC[36m$iBolt $model$ESC[0m · $ESC[34m$iFolder $currentDir$ESC[0m$gitBranch · $progress · $calls · $costStr · $iClock $timeStr$zenmuxSegment · $nowStr$weatherSegment"
