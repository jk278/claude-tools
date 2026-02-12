#!/usr/bin/env bash
# Check desktop environment and notify-send availability
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  echo "No desktop environment detected. Notifications disabled, statusline only."
  exit 0
fi
if command -v notify-send &>/dev/null; then
  echo "notify-send found. Setup complete."
else
  echo "notify-send not found. Install libnotify (e.g. apt install libnotify-bin)."
  exit 1
fi
