#!/bin/bash
# Read JSON input from stdin
input=$(cat)

# Extract context stats using jq
USED_TOKENS=$(echo "$input" | jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# Calculate total context window from percentage
if (( $(echo "$USED_PCT > 0" | bc -l) )); then
  MAX_TOKENS=$(echo "scale=0; $USED_TOKENS * 100 / $USED_PCT" | bc)
else
  MAX_TOKENS=0
fi

# Format token counts (e.g., 15234 -> 15.2k)
format_tokens() {
  local tokens=$1
  if [ "$tokens" -ge 1000 ]; then
    echo "$(echo "scale=1; $tokens / 1000" | bc)k"
  else
    echo "$tokens"
  fi
}

USED_FMT=$(format_tokens "$USED_TOKENS")
MAX_FMT=$(format_tokens "$MAX_TOKENS")

# Color based on usage (green < 50%, yellow 50-75%, red > 75%)
if (( $(echo "$USED_PCT < 50" | bc -l) )); then
  COLOR="\033[32m"  # Green
elif (( $(echo "$USED_PCT < 75" | bc -l) )); then
  COLOR="\033[33m"  # Yellow
else
  COLOR="\033[31m"  # Red
fi
RESET="\033[0m"

# Output: 68.4k/200k tokens (20%)
printf "%s/%s tokens ${COLOR}(%.0f%%)${RESET}" "$USED_FMT" "$MAX_FMT" "$USED_PCT"
