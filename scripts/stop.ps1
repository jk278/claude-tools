# Stop hook toast notification with sender icon
$AppId = 'Claude Code'
$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\assets')).Path
$AppIconPath = Join-Path $AssetsDir 'favicon.ico'
$SuccessIconPath = Join-Path $AssetsDir 'success.png'
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk"

# Auto-initialize: create shortcut with AppUserModelID if not exists
$firstRun = -not (Test-Path $ShortcutPath)
if ($firstRun) {
    # Create Start Menu shortcut
    $Wsh = New-Object -ComObject WScript.Shell
    $Sc = $Wsh.CreateShortcut($ShortcutPath)
    $Sc.TargetPath = 'powershell.exe'
    $Sc.IconLocation = $AppIconPath
    $Sc.Save()

    # Set AppUserModelID
    $CsPath = Join-Path $PSScriptRoot 'AppIdHelper.cs'
    # Add-Type: dynamically compile C# code and load into current PowerShell session
    Add-Type -Path $CsPath | Out-Null
    [AppIdHelper]::SetAppId($ShortcutPath, $AppId) | Out-Null
}

$json = $input | ConvertFrom-Json

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null

# NOTE: AppUserModelID is loaded at process startup from shortcut.
# First run: shortcut just created, AppId not yet registered to Shell → use legacy API
# Subsequent runs: new process loads registered AppId → use modern API with icon
if ($firstRun) {
    # First run: use ToastImageAndText02 template with inline icon
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)

    # Set image src (alt is optional)
    $imageNodes = $template.GetElementsByTagName('image')
    $imageNodes.Item(0).SetAttribute('src', $AppIconPath)

    # Set text
    $textNodes = $template.GetElementsByTagName('text')
    $textNodes.Item(0).InnerText = 'Work Done'
    $textNodes.Item(1).InnerText = 'Start Menu shortcut created'

    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($template)
} else {
    # Subsequent runs: ToastGeneric with auto app icon (from registered AppId)
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
}
