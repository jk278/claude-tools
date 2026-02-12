# Stop hook toast notification with quote
$AppId = 'Claude Code'
$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\assets')).Path
$SuccessIconPath = Join-Path $AssetsDir 'success.png'

$json = $input | ConvertFrom-Json

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data, ContentType=WindowsRuntime] | Out-Null

$presetsPath = Join-Path $PSScriptRoot '..\presets.json'
$configPath = Join-Path $PSScriptRoot '..\config.json'
$detail = 'Done'
try {
    $presets = Get-Content $presetsPath -Raw | ConvertFrom-Json
    $active = 'zenquotes'
    $userApis = $null
    if (Test-Path $configPath) {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($cfg.active) { $active = $cfg.active }
        $userApis = $cfg.apis
    }
    $spec = if ($userApis.$active) { $userApis.$active } else { $presets.$active }
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

$Xml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <image src="$SuccessIconPath" placement="appLogoOverride"/>
      <text>Work Done</text>
      <text hint-maxLines="3">$detail</text>
    </binding>
  </visual>
</toast>
"@

$XmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
$XmlDoc.LoadXml($Xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($XmlDoc)
