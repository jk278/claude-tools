---
description: Set up toast notifications and statusline for Claude Code (Windows only)
allowed-tools: Read, Write, Edit, Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *)
---

Windows-only. If not on Windows, inform the user and stop.

**Shell note:** The Bash tool runs through an outer shell that interprets `$`.
Use `\$env:USERPROFILE` when passing PowerShell `$env:` variables via Bash tool.

## Flow

1. Create Start Menu shortcut (toast sender identity):
```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/setup.ps1"
```

2. Read `~/.claude/settings.json` (create `{}` if missing). Preserve all existing settings.

3. Merge `statusLine` into `~/.claude/settings.json` (skip if already present):
```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/statusline.ps1\""
  }
}
```

4. Write hooks to `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`:
```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/permission.ps1\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/stop.ps1\""
          }
        ]
      }
    ]
  }
}
```

5. Write back. Report success.
