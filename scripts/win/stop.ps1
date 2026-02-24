# Stop hook toast notification with quote
$throttleFile = "$env:TEMP\claude_stop_throttle.txt"
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$last = if (Test-Path $throttleFile) { [long](Get-Content $throttleFile) } else { 0 }
if (($now - $last) -lt 300) { exit 0 }
$now | Out-File $throttleFile -Encoding UTF8

$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\assets')).Path
$SuccessIconPath = Join-Path $AssetsDir 'success.png'

$json = $input | ConvertFrom-Json

$configPath  = Join-Path $PSScriptRoot '..\..\config.json'
$presetsPath = Join-Path $PSScriptRoot '..\..\presets.json'
$detail = 'Done'
try {
    $file = if (Test-Path $configPath) { $configPath } else { $presetsPath }
    $cfg  = Get-Content $file -Raw | ConvertFrom-Json
    $spec = $cfg.apis.($cfg.active)
    if ($spec.parse -eq 'text') {
        $detail = (Invoke-WebRequest -Uri $spec.url -TimeoutSec 3 -UseBasicParsing).Content.Trim()
    } else {
        $raw = Invoke-RestMethod -Uri $spec.url -TimeoutSec 3
        $detail = $raw
        foreach ($seg in ($spec.field -replace '^\.' -split '(?=\[)|\.')) {
            if ($seg -match '^\[(\d+)\]$') { $detail = $detail[$matches[1]] }
            elseif ($seg) { $detail = $detail.$seg }
        }
    }
} catch {}

Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class AppId {
    [DllImport("shell32.dll")]
    public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string v);
}
'@
[AppId]::SetCurrentProcessExplicitAppUserModelID('Claude Code') | Out-Null

Import-Module BurntToast -ErrorAction Stop
New-BurntToastNotification -Text 'Work Done', $detail -AppLogo $SuccessIconPath
