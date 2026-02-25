---
description: Open plugin config files for editing
allowed-tools: Bash, AskUserQuestion
---

Plugin root: `${CLAUDE_PLUGIN_ROOT}`

Files:
- `config.json` — quote API (`{ "active": "zenquotes", "apis": { "<name>": { "url", "parse", "field?" } } }`)
- `.env` — usage providers + secrets (gitignored)
- `presets.json` — built-in APIs reference (read-only): `zenquotes`, `jinrishici`
- `.env.example` — `.env` format reference
- `weather.json` — weather config: env var name declarations for `hostEnv`, `locationEnv`, `keyEnv`

## Flow

1. Print the absolute path of `${CLAUDE_PLUGIN_ROOT}`.
2. Run `find "$(dirname "$CLAUDE_PLUGIN_ROOT")" -maxdepth 1 -mindepth 1 -type d | sort` via Bash to list sibling version directories. Identify the most-recent prior version as `PRIOR_VERSION_ROOT` (empty if none exists).
3. Use `test -f` via Bash to check if `config.json` exists. If not:
   a. Check if `$PRIOR_VERSION_ROOT/config.json` exists.
   b. If yes, copy it to `$CLAUDE_PLUGIN_ROOT/config.json` via Bash `cp`; otherwise copy `presets.json`.
4. Use `test -f` via Bash to check if `.env` exists. If not:
   a. Check if `$PRIOR_VERSION_ROOT/.env` exists.
   b. If yes, copy it to `$CLAUDE_PLUGIN_ROOT/.env` via Bash `cp`; otherwise copy `.env.example`.
5. Print a summary of all copy actions taken in steps 3–4.
6. If any file was copied from a prior version, report success, remind the user to run `/claude-tools:config` again to customize, and stop.
7. Ask the user which file to configure: **Usages/Weather** (`.env`) or **Quote API** (`config.json`).
8. Detect editor: check `zed` first, then `code`. Open the selected file. If neither is available, print the absolute path of the file and tell the user to edit it manually.
