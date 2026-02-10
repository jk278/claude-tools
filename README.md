# claude-toast

Windows toast notifications for Claude Code.

- **Permission** — notifies when Claude requests tool permission (PermissionRequest)
- **Work Done** — notifies when Claude finishes a task (Stop), with a daily quote
- **Statusline** — rich status bar showing model, git branch, context usage, API calls, cost, and duration

## Requirements

- Windows 10+
- PowerShell 5.1+

## Install

```
/plugin marketplace add jk278/claude-toast
/plugin install claude-toast
```

## Statusline

Run `/claude-toast:statusline` to configure. Displays model, directory, git branch, context %, API calls, cost, and session duration.

## Uninstall

Run `/claude-toast:reset` before uninstalling to remove the Start Menu shortcut.

## How it works

On first run, a Start Menu shortcut is created with a custom `AppUserModelID` (`Claude Code`). This allows Windows to display the Claude icon as the toast sender. Subsequent notifications use the registered identity for a native look.
