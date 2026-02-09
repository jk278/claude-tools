---
description: Configure quote API for toast notifications
allowed-tools: Read, Write, Edit, AskUserQuestion
---

Config: `${CLAUDE_PLUGIN_ROOT}/config.json`
Default active: `zenquotes`

Presets:
- `zenquotes` — English daily quote (zenquotes.io)
- `jinrishici` — Chinese classical poetry (今日诗词)

## Flow

1. Read config.json (if exists) to get current `active`. Ask the user to choose from presets above + any custom APIs in config `apis`, marking active with "(current)", plus "Add custom API".
2. Existing API → set `active` in config.json.
3. Add custom → ask name, URL, parse (`text`/`json`), field (if json). Example entry: `{ "url": "...", "parse": "json", "field": "[0].q" }`. Add to `apis` and set `active`.
