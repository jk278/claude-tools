# claude-toast

Windows toast notifications for Claude Code.

- **Permission** — notifies when Claude requests tool permission (PermissionRequest)
- **Work Done** — notifies when Claude finishes a task (Stop), with a daily quote

## Requirements

- Windows 10+
- PowerShell 5.1+

## Install

```
/plugin marketplace add jk278/claude-toast
/plugin install claude-toast
```

## How it works

On first run, a Start Menu shortcut is created with a custom `AppUserModelID` (`Claude Code`). This allows Windows to display the Claude icon as the toast sender. Subsequent notifications use the registered identity for a native look.
