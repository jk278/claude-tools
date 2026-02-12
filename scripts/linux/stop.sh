#!/usr/bin/env bash
# Stop hook notification with quote via notify-send
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  cat > /dev/null; printf '\a'; exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON="$SCRIPT_DIR/../../assets/success.png"
PRESETS="$SCRIPT_DIR/../../presets.json"
CONFIG="$SCRIPT_DIR/../../config.json"

json=$(cat)
detail="Done"

if command -v jq &>/dev/null && [ -f "$PRESETS" ]; then
  active="zenquotes"
  user_apis="{}"
  if [ -f "$CONFIG" ]; then
    cfg_active=$(jq -r '.active // empty' "$CONFIG")
    [ -n "$cfg_active" ] && active="$cfg_active"
    user_apis=$(jq -r '.apis // {}' "$CONFIG")
  fi

  # User API takes priority over preset
  spec=$(echo "$user_apis" | jq -r ".[\"$active\"] // empty")
  [ -z "$spec" ] && spec=$(jq -r ".[\"$active\"]" "$PRESETS")

  parse=$(echo "$spec" | jq -r '.parse')
  url=$(echo "$spec" | jq -r '.url')

  if [ "$parse" = "text" ]; then
    result=$(curl -sf --max-time 3 "$url") && [ -n "$result" ] && detail="$result"
  else
    field=$(echo "$spec" | jq -r '.field')
    result=$(curl -sf --max-time 3 "$url") && [ -n "$result" ] && {
      detail=$(echo "$result" | jq -r "$field")
    }
  fi
fi

notify-send -i "$ICON" "Work Done" "$detail"
