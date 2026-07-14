#!/bin/bash

# Requires: jq
if ! command -v jq &>/dev/null; then
  echo "statusline: jq required" >&2
  exit 1
fi

# Read JSON input from stdin
input=$(cat)

# Extract context stats using jq
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
USED_TOKENS=$(echo "$input" | jq -r '
  (.context_window.current_usage // {}) as $u
  | (($u.input_tokens // 0)
     + ($u.output_tokens // 0)
     + ($u.cache_creation_input_tokens // 0)
     + ($u.cache_read_input_tokens // 0))
')
MODEL=$(echo "$input" | jq -r '.model.display_name // .model // "unknown"')

# Format token count as "Nk" (e.g. 14523 -> "14k", 1234567 -> "1.2M")
format_tokens() {
  local n=$1
  n=${n%.*}
  if [ "$n" -ge 1000000 ]; then
    awk -v n="$n" 'BEGIN { printf "%.2fM", n/1000000 }'
  elif [ "$n" -ge 1000 ]; then
    awk -v n="$n" 'BEGIN { printf "%.2fk", n/1000 }'
  else
    echo "$n"
  fi
}
TOKENS_LABEL=$(format_tokens "$USED_TOKENS")

# Git branch of the workspace dir, dimmed
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
BRANCH=$(git -C "${DIR:-.}" branch --show-current 2>/dev/null)
BRANCH_LABEL=""
if [ -n "$BRANCH" ]; then
  # Branch name passed as %s so it can't corrupt the printf format
  BRANCH_LABEL=$(printf ' | \033[38;5;244m⎇ %s\033[0m' "$BRANCH")
fi

# Before the first response there's no usage yet — show model + branch only
if (( $(echo "$USED_PCT == 0" | bc -l) )); then
  printf "%s%s" "$MODEL" "$BRANCH_LABEL"
  exit 0
fi

# Clamp raw percentage to 0-100
CLAMPED_PCT=$(echo "if ($USED_PCT < 0) 0 else if ($USED_PCT > 100) 100 else $USED_PCT" | bc -l)

# Build progress bar: 10 squares spanning 0-100% (each square = 10%, half = 5%)
FULL_SQUARES=$(echo "scale=0; $CLAMPED_PCT / 10" | bc)
if [ "$FULL_SQUARES" -gt 10 ]; then
  FULL_SQUARES=10
fi

REMAINDER=$(echo "scale=1; $CLAMPED_PCT - ($FULL_SQUARES * 10)" | bc)
if [ "$FULL_SQUARES" -lt 10 ] && (( $(echo "$REMAINDER >= 5" | bc -l) )); then
  HAS_HALF=1
else
  HAS_HALF=0
fi

EMPTY_SQUARES=$((10 - FULL_SQUARES - HAS_HALF))
if [ "$EMPTY_SQUARES" -lt 0 ]; then
  EMPTY_SQUARES=0
fi

# Bar cells sit on a dim background so the half block ▌ has no gap on its right
BAR=""
for ((i=0; i<FULL_SQUARES; i++)); do
  BAR+="█"
done
if [ "$HAS_HALF" -eq 1 ]; then
  BAR+="▌"
fi
for ((i=0; i<EMPTY_SQUARES; i++)); do
  BAR+=" "
done
BAR_BG="\033[48;5;236m"

RESET="\033[0m"

# Token count and bar share one color, by absolute usage: green ≤100k, yellow 100k-600k, red >600k
TOKENS_INT=${USED_TOKENS%.*}
if [ "$TOKENS_INT" -le 100000 ]; then
  TOKEN_COLOR="\033[32m"
elif [ "$TOKENS_INT" -le 600000 ]; then
  TOKEN_COLOR="\033[33m"
else
  TOKEN_COLOR="\033[31m"
fi

# Output: Opus 4.5 | 14k ████████▌ 89% | ⎇ master
printf "%s | ${TOKEN_COLOR}%s${RESET} ${TOKEN_COLOR}${BAR_BG}%s${RESET}${TOKEN_COLOR} %.0f%%${RESET}%s" "$MODEL" "$TOKENS_LABEL" "$BAR" "$CLAMPED_PCT" "$BRANCH_LABEL"
