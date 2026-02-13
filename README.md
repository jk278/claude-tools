# claude-tools

Toast notifications, statusline, and agent skills for Claude Code.

- **Permission** — notifies when Claude requests tool permission (PermissionRequest)
- **Work Done** — notifies when Claude finishes a task (Stop), with a daily quote
- **Statusline** — rich status bar showing model, git branch, context usage, API calls, cost, and duration
- **Codex** — invoke OpenAI Codex CLI (codex exec, codex resume) from Claude Code

## Requirements

- Windows 10+ or Linux

## Install

```
/plugin marketplace add jk278/claude-tools
/plugin install claude-tools
```

## Setup

Run `/claude-tools:setup` to enable toast notifications and statusline. This writes hooks and statusLine config into `~/.claude/settings.json` and creates the Start Menu shortcut for toast sender identity.

## Uninstall

Run `/claude-tools:reset` before uninstalling to remove the Start Menu shortcut.

## How it works

On first setup, a Start Menu shortcut is created with a custom `AppUserModelID` (`Claude Code`). This allows Windows to display the Claude icon as the toast sender. Subsequent notifications use the registered identity for a native look.
