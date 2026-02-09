# Permission toast notification
$AppId = 'Claude Code'
$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\assets')).Path
$AppIconPath = Join-Path $AssetsDir 'favicon.ico'
$HelpIconPath = Join-Path $AssetsDir 'help.png'
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
$toolName = $json.tool_name
$toolInput = $json.tool_input

# Build detail text based on tool type (no truncation)
$detail = switch ($toolName) {
    { $_ -in @('Read', 'Edit', 'Write') } {
        "$toolName`: $(Split-Path $toolInput.file_path -Leaf)"
    }
    { $_ -in @('Glob', 'Grep') } {
        "$toolName`: $($toolInput.pattern)"
    }
    { $_ -in @('Bash', 'Task') } {
        "$toolName`: $($toolInput.description)"
    }
    'AskUserQuestion' {
        "Ask: $($toolInput.questions[0].question)"
    }
    default { $toolName }
}

# NOTE: AppUserModelID is loaded at process startup from shortcut.
# First run: shortcut just created, AppId not yet registered to Shell → use legacy API
# Subsequent runs: new process loads registered AppId → use modern API with auto sender icon
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null

if ($firstRun) {
    # First run: use ToastImageAndText02 template with inline icon
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)

    # Set inline icon (alt is optional)
    $imageNodes = $template.GetElementsByTagName('image')
    $imageNodes.Item(0).SetAttribute('src', $AppIconPath)

    # Set text
    $textNodes = $template.GetElementsByTagName('text')
    $textNodes.Item(0).InnerText = 'Permission'
    $textNodes.Item(1).InnerText = 'Start Menu shortcut created'

    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($template)
} else {
    # Subsequent runs: ToastGeneric with auto sender icon (from registered AppId)
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data, ContentType=WindowsRuntime] | Out-Null

    $Xml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <image src="$HelpIconPath" placement="appLogoOverride"/>
      <text>Permission</text>
      <text hint-maxLines="3">$detail</text>
    </binding>
  </visual>
</toast>
"@

    $XmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $XmlDoc.LoadXml($Xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($XmlDoc)
}
