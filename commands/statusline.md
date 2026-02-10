---
description: Configure statusline for Claude Code
allowed-tools: Read, Write, Edit
---

Set the statusLine in user settings to use the plugin's statusline script.

## Flow

1. Read `~/.claude/settings.json` (or create if not exists). Preserve all existing settings.
2. Merge in:
```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/statusline.ps1\""
  }
}
```
3. Write back the merged settings. Report success.
