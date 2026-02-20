#!/usr/bin/env bash
# Statusline: model, directory, git branch, context %, calls, cost, duration
ESC=$'\033'
SHOW_COST=true

# Nerd Font icons
i_bolt=$'\uf0e7'    # nf-fa-bolt
i_folder=$'\uf07b'  # nf-fa-folder
i_branch=$'\ue0a0'  # nf-pl-branch
i_cube=$'\uf292'    # nf-fa-hashtag
i_clock=$'\uf017'   # nf-fa-clock_o
i_zenmux=$'\uf080'  # nf-fa-bar-chart
i_refresh=$'\uf021' # nf-fa-refresh
i_usd=$'\uf155'     # nf-fa-usd
i_up=$'\uf093'      # nf-fa-upload
i_down=$'\uf019'    # nf-fa-download
i_calendar=$'\uf073' # nf-fa-calendar
i_cloud=$'\uf0c2'    # nf-fa-cloud

json=$(cat)
model=$(echo "$json" | jq -r '.model.display_name')
current_dir=$(echo "$json" | jq -r '.workspace.current_dir' | xargs basename)
session_id=$(echo "$json" | jq -r '.session_id[:8]')

# Git branch
git_branch=""
if [ -d .git ]; then
  head=$(cat .git/HEAD 2>/dev/null)
  if [[ "$head" =~ ref:\ refs/heads/(.*) ]]; then
    git_branch=" · ${ESC}[38;5;97m${i_branch} ${BASH_REMATCH[1]}${ESC}[0m"
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
in_tokens=$(echo "$json"  | jq -r '.context_window.total_input_tokens // 0')
out_tokens=$(echo "$json" | jq -r '.context_window.total_output_tokens // 0')

# Duration formatting (xhx)
duration_ms=$(echo "$json" | jq -r '.cost.total_duration_ms // 0')
d_int=$(awk "BEGIN { printf \"%d\", $duration_ms / 3600000 }")
d_tenth=$(awk "BEGIN { printf \"%d\", int(($duration_ms / 3600000 - $d_int) * 10) }")
time_str="${ESC}[90m${d_int}h${d_tenth/#0/}${ESC}[0m"

# Progress bar (█ / ░)
bar_size=10
filled=$(( display_percent * bar_size / 100 ))
empty=$(( bar_size - filled ))
char_filled=$'\u2588'; char_empty=$'\u2591'
bar=$(printf "${char_filled}%.0s" $(seq 1 $filled 2>/dev/null))$(printf "${char_empty}%.0s" $(seq 1 $empty 2>/dev/null))
if (( display_percent > 80 )); then
  percent_color="${ESC}[33m"
else
  percent_color="${ESC}[32m"
fi
progress="${percent_color}${bar} ${display_percent}%${ESC}[0m"

calls="${ESC}[38;5;208m${i_cube} ${current_calls}c${ESC}[0m"

if $SHOW_COST; then
  cost_fmt=$(awk "BEGIN { printf \"%.2f\", $cost }")
  cost_str="${ESC}[38;5;136m${i_usd} ${cost_fmt}${ESC}[0m"
else
  fmt_tokens() {
    local n=$1
    if (( n >= 1048576 )); then awk "BEGIN { printf \"%.1fM\", $n/1048576 }"
    else awk "BEGIN { printf \"%dk\", int($n/1024) }"; fi
  }
  cost_str="${ESC}[90m${i_up} ${ESC}[0m${ESC}[38;5;136m$(fmt_tokens "$in_tokens")${ESC}[0m ${ESC}[90m${i_down} ${ESC}[0m${ESC}[38;5;136m$(fmt_tokens "$out_tokens")${ESC}[0m"
fi

# ===== Zenmux Usage =====
zenmux_segment=""
plugin_root="$(cd "$(dirname "$0")/../.." && pwd)"

# Load .env once (shared by all provider blocks)
_env_file="$plugin_root/.env"
if [ -f "$_env_file" ]; then
    set -a; source "$_env_file"; set +a
fi

usages_file="$plugin_root/usages.json"

format_z_reset() {
  local end_str="$1" end_ts left_s l_int l_tenth
  end_ts=$(date -d "$end_str UTC" +%s 2>/dev/null) || return
  left_s=$(( end_ts - $(date -u +%s) ))
  (( left_s <= 0 )) && return
  l_int=$(awk "BEGIN { printf \"%d\", $left_s / 3600 }")
  l_tenth=$(awk "BEGIN { printf \"%d\", int(($left_s / 3600 - $l_int) * 10) }")
  echo " ${i_refresh} ${l_int}h${l_tenth/#0/}"
}

z_col() {
  local pct; pct=$(awk "BEGIN { printf \"%d\", $1 * 100 }")
  (( pct >= 90 )) && echo "${ESC}[31m" && return
  (( pct >= 70 )) && echo "${ESC}[33m" && return
  echo "${ESC}[32m"
}

if [ -f "$usages_file" ]; then
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

    if [ -z "$z_session_id" ] || [ -z "$z_session_sig" ]; then
      zenmux_segment=" · ${ESC}[31m${i_zenmux} !cfg${ESC}[0m"
    else
      z_cache_file="/tmp/claude_zenmux_usage_cache.txt"
      z_now=$(date -u +%s)
      week_rate=""; hour5_rate=""; week_end=""; h5_end=""

      if [ -f "$z_cache_file" ]; then
        IFS='|' read -r _ch _he _cw _we _cts < "$z_cache_file"
        if (( z_now - _cts < 60 )) && [ -n "$_he" ]; then
          hour5_rate="$_ch"; h5_end="$_he"; week_rate="$_cw"; week_end="$_we"
        fi
      fi

      if [ -z "$week_rate" ]; then
        _resp=$(curl -s --max-time 3 \
          "https://zenmux.ai/api/subscription/get_current_usage" \
          -H "Cookie: sessionId=${z_session_id}; sessionId.sig=${z_session_sig}" 2>/dev/null)
        if echo "$_resp" | jq -e '.success == true' > /dev/null 2>&1; then
          week_rate=$(echo "$_resp"  | jq -r '.data[] | select(.periodType=="week")   | .usedRate')
          hour5_rate=$(echo "$_resp" | jq -r '.data[] | select(.periodType=="hour_5") | .usedRate')
          week_end=$(echo "$_resp"   | jq -r '.data[] | select(.periodType=="week")   | .cycleEndTime')
          h5_end=$(echo "$_resp"     | jq -r '.data[] | select(.periodType=="hour_5") | .cycleEndTime')
          echo "${hour5_rate}|${h5_end}|${week_rate}|${week_end}|${z_now}" > "$z_cache_file"
        elif [ -n "$_resp" ]; then
          zenmux_segment=" · ${ESC}[31m${i_zenmux} !auth${ESC}[0m"
        else
          zenmux_segment=" · ${ESC}[90m${i_zenmux} …${ESC}[0m"
        fi
      fi

      if [ -n "$week_rate" ] && [ -n "$hour5_rate" ]; then
        w_pct=$(awk  "BEGIN { printf \"%d\", $week_rate  * 100 }")
        h5_pct=$(awk "BEGIN { printf \"%d\", $hour5_rate * 100 }")
        w_col=$(z_col "$week_rate"); h5_col=$(z_col "$hour5_rate")
        h5_reset=$(format_z_reset "$h5_end")
        w_reset=$(format_z_reset "$week_end")
        zenmux_segment=" · ${i_zenmux} ${h5_col}H${h5_pct}%${ESC}[0m${h5_reset} / ${w_col}W${w_pct}%${ESC}[0m${w_reset}"
      fi
    fi
  fi
fi

# ===== Weather =====
weather_segment=""
weather_file="$plugin_root/weather.json"

if [ -f "$weather_file" ]; then
    if [ "${QWEATHER_ENABLED:-}" = "true" ]; then
        w_host_env=$(jq -r '.hostEnv'     "$weather_file")
        w_loc_env=$(jq -r  '.locationEnv' "$weather_file")
        w_key_env=$(jq -r  '.keyEnv'      "$weather_file")
        w_host="${!w_host_env}"; w_loc="${!w_loc_env}"; w_key="${!w_key_env}"

        if [ -z "$w_host" ] || [ -z "$w_loc" ] || [ -z "$w_key" ]; then
            weather_segment=" · ${ESC}[31m${i_cloud} !cfg${ESC}[0m"
        else
            w_cache_file="/tmp/claude_weather_cache.txt"
            w_now=$(date -u +%s)
            w_temp=""; w_text=""; w_max=""; w_min=""

            if [ -f "$w_cache_file" ]; then
                IFS='|' read -r _wt _wmax _wmin _wts _wtxt < "$w_cache_file"
                if (( w_now - _wts < 600 )) && [ -n "$_wt" ]; then
                    w_temp="$_wt"; w_max="$_wmax"; w_min="$_wmin"; w_text="$_wtxt"
                fi
            fi

            if [ -z "$w_temp" ]; then
                _now_resp=$(curl -s --max-time 3 \
                    "$w_host/v7/weather/now?location=$w_loc&lang=en" \
                    -H "X-QW-Api-Key: $w_key" 2>/dev/null)
                _fc_resp=$(curl -s --max-time 3 \
                    "$w_host/v7/weather/3d?location=$w_loc&lang=en" \
                    -H "X-QW-Api-Key: $w_key" 2>/dev/null)

                _now_code=$(echo "$_now_resp" | jq -r '.code // empty' 2>/dev/null)
                _fc_code=$(echo  "$_fc_resp"  | jq -r '.code // empty' 2>/dev/null)

                if [ "$_now_code" = "200" ] && [ "$_fc_code" = "200" ]; then
                    w_temp=$(echo "$_now_resp" | jq -r '.now.temp')
                    w_text=$(echo "$_now_resp" | jq -r '.now.text')
                    w_max=$(echo  "$_fc_resp"  | jq -r '.daily[0].tempMax')
                    w_min=$(echo  "$_fc_resp"  | jq -r '.daily[0].tempMin')
                    printf '%s|%s|%s|%s|%s' "$w_temp" "$w_max" "$w_min" "$w_now" "$w_text" > "$w_cache_file"
                elif [ -n "$_now_resp" ] || [ -n "$_fc_resp" ]; then
                    weather_segment=" · ${ESC}[31m${i_cloud} !api${ESC}[0m"
                else
                    weather_segment=" · ${ESC}[90m${i_cloud} …${ESC}[0m"
                fi
            fi

            if [ -n "$w_temp" ]; then
                weather_segment=" · ${i_cloud} ${ESC}[36m${w_temp}°${ESC}[0m ${w_text} ${ESC}[90m${w_min}~${w_max}°${ESC}[0m"
            fi
        fi
    fi
fi

# Output
now_str="${ESC}[90m${i_calendar} ${ESC}[0m$(date +"%m-%d %H:%M")"
echo "${ESC}[36m${i_bolt} ${model}${ESC}[0m · ${ESC}[34m${i_folder} ${current_dir}${ESC}[0m${git_branch} · ${progress} · ${calls} · ${cost_str} · ${i_clock} ${time_str}${zenmux_segment} · ${now_str}${weather_segment}"
