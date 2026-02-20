#!/usr/bin/env bash
# Statusline: model, directory, git branch, context %, calls, cost, duration
ESC=$'\033'
SHOW_COST=true

json=$(cat)
model=$(echo "$json" | jq -r '.model.display_name')
current_dir=$(echo "$json" | jq -r '.workspace.current_dir' | xargs basename)
session_id=$(echo "$json" | jq -r '.session_id[:8]')

# Git branch
git_branch=""
if [ -d .git ]; then
  head=$(cat .git/HEAD 2>/dev/null)
  if [[ "$head" =~ ref:\ refs/heads/(.*) ]]; then
    git_branch=" · ${ESC}[38;5;97m⎇ ${BASH_REMATCH[1]}${ESC}[0m"
  fi
fi

# Cache for context percent
cache_file="/tmp/claude_statusline_cache.txt"
cached_percent="0"
cached_session=""
if [ -f "$cache_file" ]; then
  IFS='|' read -r cached_percent cached_session < "$cache_file"
fi
[ "$cached_session" != "$session_id" ] && cached_percent="0"

# Context usage
display_percent="$cached_percent"
input_tokens=$(echo "$json" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_creation=$(echo "$json" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$json" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
context_size=$(echo "$json" | jq -r '.context_window.context_window_size // 0')
current_tokens=$((input_tokens + cache_creation + cache_read))
if (( context_size > 0 && current_tokens > 0 )); then
  display_percent=$(( current_tokens * 100 / context_size ))
  echo "${display_percent}|${session_id}" > "$cache_file"
fi

# API calls from transcript
current_calls=0
transcript=$(echo "$json" | jq -r '.transcript_path // empty')
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  current_calls=$(jq -r 'select(.message.usage != null and .isSidechain != true and .isApiErrorMessage != true)' "$transcript" | jq -s 'length')
fi

# Cost or tokens
cost=$(echo "$json" | jq -r '.cost.total_cost_usd // 0')

# Duration
duration_ms=$(echo "$json" | jq -r '.cost.total_duration_ms // 0')
hours=$(awk "BEGIN { printf \"%.1f\", $duration_ms / 3600000 }")
time_str="${ESC}[90m${hours}h${ESC}[0m"

# Progress bar
bar_size=10
filled=$(( display_percent * bar_size / 100 ))
empty=$(( bar_size - filled ))
bar=$(printf '■%.0s' $(seq 1 $filled 2>/dev/null))$(printf '□%.0s' $(seq 1 $empty 2>/dev/null))
if (( display_percent > 80 )); then
  percent_color="${ESC}[33m"
else
  percent_color="${ESC}[32m"
fi
progress="${percent_color}${bar} ${display_percent}%${ESC}[0m"

calls="${ESC}[38;5;208m⬡ ${current_calls}c${ESC}[0m"

if $SHOW_COST; then
  cost_fmt=$(awk "BEGIN { printf \"%.2f\", $cost }")
  cost_str="${ESC}[38;5;136m\$${cost_fmt}${ESC}[0m"
fi

# ===== Zenmux Usage =====
zenmux_segment=""
plugin_root="$(cd "$(dirname "$0")/../.." && pwd)"
usages_file="$plugin_root/usages.json"

if [ -f "$usages_file" ]; then
  env_file="$plugin_root/.env"
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi

  zenmux_enabled=false
  IFS=',' read -ra _providers <<< "${ENABLED_PROVIDER:-}"
  for _p in "${_providers[@]}"; do
    [ "${_p// /}" = "zenmux" ] && zenmux_enabled=true
  done

  if $zenmux_enabled; then
    _sid_env=$(jq -r '.zenmux.sessionIdEnv' "$usages_file")
    _sig_env=$(jq -r '.zenmux.sessionSigEnv' "$usages_file")
    z_session_id="${!_sid_env}"
    z_session_sig="${!_sig_env}"

    if [ -n "$z_session_id" ] && [ -n "$z_session_sig" ]; then
      z_cache_file="/tmp/zenmux_usage_cache.txt"
      z_now=$(date +%s)
      week_rate=""; hour5_rate=""

      if [ -f "$z_cache_file" ]; then
        IFS='|' read -r _cw _ch _cts < "$z_cache_file"
        (( z_now - _cts < 60 )) && week_rate="$_cw" && hour5_rate="$_ch"
      fi

      if [ -z "$week_rate" ]; then
        _resp=$(curl -s --max-time 3 \
          "https://zenmux.ai/api/subscription/get_current_usage" \
          -H "Cookie: sessionId=${z_session_id}; sessionId.sig=${z_session_sig}" 2>/dev/null)
        if echo "$_resp" | jq -e '.success' > /dev/null 2>&1; then
          week_rate=$(echo "$_resp"  | jq -r '.data[] | select(.periodType=="week")   | .usedRate')
          hour5_rate=$(echo "$_resp" | jq -r '.data[] | select(.periodType=="hour_5") | .usedRate')
          echo "${week_rate}|${hour5_rate}|${z_now}" > "$z_cache_file"
        fi
      fi

      if [ -n "$week_rate" ] && [ -n "$hour5_rate" ]; then
        _zcol() {
          local pct; pct=$(awk "BEGIN { printf \"%d\", $1 * 100 }")
          (( pct >= 90 )) && echo "${ESC}[31m" && return
          (( pct >= 70 )) && echo "${ESC}[33m" && return
          echo "${ESC}[32m"
        }
        w_pct=$(awk  "BEGIN { printf \"%d\", $week_rate  * 100 }")
        h5_pct=$(awk "BEGIN { printf \"%d\", $hour5_rate * 100 }")
        zenmux_segment=" · Z: $(_zcol "$week_rate")${w_pct}%${ESC}[0m $(_zcol "$hour5_rate")${h5_pct}%${ESC}[0m"
      fi
    fi
  fi
fi

# Output
echo "${ESC}[36m⚡${model}${ESC}[0m · ${ESC}[34m□ ${current_dir}${ESC}[0m${git_branch} · ${progress} · ${calls} · ${cost_str} · ⧖ ${time_str}${zenmux_segment}"
