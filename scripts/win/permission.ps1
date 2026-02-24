# Permission toast notification
$throttleFile = "$env:TEMP\claude_permission_throttle.txt"
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$last = if (Test-Path $throttleFile) { [long](Get-Content $throttleFile) } else { 0 }
$now | Out-File $throttleFile -Encoding UTF8
if (($now - $last) -lt 60) { exit 0 }

$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\assets')).Path
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

Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class AppId {
    [DllImport("shell32.dll")]
    public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string v);
}
'@
[AppId]::SetCurrentProcessExplicitAppUserModelID('Claude Code') | Out-Null

Import-Module BurntToast -ErrorAction Stop
New-BurntToastNotification -Text 'Permission', $detail -AppLogo $HelpIconPath
