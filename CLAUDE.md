# claude-tools

Windows toast notification plugin for Claude Code.

## Structure

```
assets/          Icons (favicon.ico, help.png, success.png)
commands/        Slash commands (*.md with frontmatter)
skills/          Agent skills (SKILL.md per skill directory)
hooks/           Empty (hooks registered via setup command)
scripts/
  win/           Windows PowerShell scripts
  linux/         Linux shell scripts
presets.json     Built-in quote API definitions (read-only)
config.json      User config: active API + custom APIs (gitignored)
```

## Setup

Run `/claude-tools:setup` to enable. Writes hooks and statusLine into `~/.claude/settings.json` and creates the Start Menu shortcut for toast sender identity.

## Hooks

- `PermissionRequest` → `scripts/win/permission.ps1` — tool permission toast
- `Stop` → `scripts/win/stop.ps1` — task completion toast with quote

## Quote API

- Presets defined in `presets.json`, user config in `config.json`
- `stop.ps1` merges both: user custom APIs take priority over presets
- Default active: `zenquotes` (when no config.json)
- Config format: `{ "active": "<name>", "apis": { "<name>": { "url", "parse", "field?" } } }`

## Versioning

Version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync. Bump both when releasing.

## Scripts

- `win/setup.ps1` — create Start Menu shortcut with `AppUserModelID` for toast sender identity
- `win/permission.ps1` — switch on `tool_name` to build detail text
- `win/stop.ps1` — fetch quote from active API, fallback to "Done"
- `win/statusline.ps1` — rich status bar (model, git branch, context %, calls, cost, duration)
- `win/reset.ps1` — remove Start Menu shortcut
