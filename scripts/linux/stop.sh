#!/usr/bin/env bash
# Stop hook notification with quote via notify-send
throttle_file="/tmp/claude_stop_throttle.txt"
now=$(date -u +%s)
last=0; [ -f "$throttle_file" ] && last=$(cat "$throttle_file")
(( now - last < 300 )) && exit 0
echo "$now" > "$throttle_file"

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  cat > /dev/null; printf '\a'; exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON="$SCRIPT_DIR/../../assets/success.png"
PRESETS="$SCRIPT_DIR/../../presets.json"
CONFIG="$SCRIPT_DIR/../../config.json"

json=$(cat)
detail="Done"

if command -v jq &>/dev/null; then
  file="$CONFIG"; [ -f "$file" ] || file="$PRESETS"
  active=$(jq -r '.active' "$file")
  spec=$(jq -r ".apis[\"$active\"]" "$file")

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
