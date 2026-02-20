---
description: Open plugin config files for editing
allowed-tools: Bash, Write, AskUserQuestion
---

Plugin root: `${CLAUDE_PLUGIN_ROOT}`

Files:
- `config.json` — quote API (`{ "active": "zenquotes", "apis": { "<name>": { "url", "parse", "field?" } } }`)
- `.env` — usage providers + secrets (gitignored)
- `presets.json` — built-in APIs reference (read-only): `zenquotes`, `jinrishici`
- `.env.example` — `.env` format reference

## Flow

1. Print the absolute path of `${CLAUDE_PLUGIN_ROOT}`.
2. Ask the user which file to configure: `config.json` (quote API) or `.env` (usage providers / secrets).
3. If `.env` selected and it does not exist, copy from `.env.example`.
4. Detect editor: check `zed` first, then `code`. Open the selected file with the found editor. If neither is available, print the absolute path of the file and tell the user to edit it manually.
