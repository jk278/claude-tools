# Permission toast notification
$AppId = 'Claude Code'
$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\assets')).Path
$HelpIconPath = Join-Path $AssetsDir 'help.png'

$json = $input | ConvertFrom-Json
$toolName = $json.tool_name
$toolInput = $json.tool_input

# Build detail text based on tool type
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

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
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
