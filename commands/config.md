---
description: Open plugin config files for editing
allowed-tools: Bash, Read, Write, AskUserQuestion
---

Plugin root: `${CLAUDE_PLUGIN_ROOT}`

Files:
- `config.json` — quote API (`{ "active": "zenquotes", "apis": { "<name>": { "url", "parse", "field?" } } }`)
- `.env` — usage providers + secrets (gitignored)
- `presets.json` — built-in APIs reference (read-only): `zenquotes`, `jinrishici`
- `.env.example` — `.env` format reference

## Flow

1. Print the absolute path of `${CLAUDE_PLUGIN_ROOT}`.
2. If `config.json` does not exist, copy `presets.json` to `config.json`.
3. If `.env` does not exist, copy from `.env.example`.
4. Ask the user which file to configure: **Quote API** (`config.json`) or **Usage provider credentials** (`.env`).
5. Detect editor: check `zed` first, then `code`. Open the selected file. If neither is available, print the absolute path of the file and tell the user to edit it manually.
