# Remove Start Menu shortcut to reset AppUserModelID registration
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk"
if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
    Write-Host 'Shortcut removed. Toast identity will re-register on next notification.'
} else {
    Write-Host 'No shortcut found.'
}
