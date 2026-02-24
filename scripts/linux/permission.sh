#!/usr/bin/env bash
# Permission hook notification via notify-send
throttle_file="/tmp/claude_permission_throttle.txt"
now=$(date -u +%s)
last=0; [ -f "$throttle_file" ] && last=$(cat "$throttle_file")
echo "$now" > "$throttle_file"
(( now - last < 60 )) && exit 0

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  cat > /dev/null; printf '\a'; exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON="$SCRIPT_DIR/../../assets/help.png"

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name')
tool_input=$(echo "$json" | jq -r '.tool_input')

case "$tool_name" in
  Read|Edit|Write)
    file=$(echo "$tool_input" | jq -r '.file_path' | xargs basename)
    detail="$tool_name: $file" ;;
  Glob|Grep)
    pattern=$(echo "$tool_input" | jq -r '.pattern')
    detail="$tool_name: $pattern" ;;
  Bash|Task)
    desc=$(echo "$tool_input" | jq -r '.description')
    detail="$tool_name: $desc" ;;
  AskUserQuestion)
    q=$(echo "$tool_input" | jq -r '.questions[0].question')
    detail="Ask: $q" ;;
  *)
    detail="$tool_name" ;;
esac

notify-send -i "$ICON" "Permission" "$detail"
