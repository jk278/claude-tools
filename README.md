# claude-tools

Toast notifications, statusline, and agent skills for Claude Code.

- **Permission** — notifies when Claude requests tool permission (PermissionRequest)
- **Work Done** — notifies when Claude finishes a task (Stop), with a daily quote
- **Statusline** — rich status bar showing model, git branch, context usage, API calls, cost, and duration
- **Codex** — invoke OpenAI Codex CLI (codex exec, codex resume) from Claude Code

## Requirements

- Windows 10+ with PowerShell 7 (`pwsh`) or Linux
- Terminal using a [Nerd Font](https://www.nerdfonts.com/) for statusline icons (recommended: [JetBrains Maple Mono](https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono))

## Install

```
/plugin marketplace add jk278/claude-tools
/plugin install claude-tools
```

## Setup

Run `/claude-tools:setup` to enable toast notifications and statusline. This writes hooks and statusLine config into `~/.claude/settings.json` and creates the Start Menu shortcut for toast sender identity.

## Update

```
/plugin marketplace update
/plugin update claude-tools
```

After updating, restart your shell — if using VS Code or Alacritty, restart the application. Then re-run setup and config:

```
/claude-tools:setup
/claude-tools:config
```

## Uninstall

Uninstalling the plugin does not remove the Start Menu shortcut. Setup may have installed the BurntToast module if it wasn't already present. Remove manually if needed:

```powershell
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk" -Force
Uninstall-Module BurntToast
```

## How it works

On setup, a Start Menu shortcut is created with a custom `AppUserModelID` (`Claude Code`). This allows Windows to display the Claude icon as the toast sender. Re-running setup updates the shortcut in place.
