#!/bin/bash
# Read JSON input from stdin
input=$(cat)

# Extract context stats using jq
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
MODEL=$(echo "$input" | jq -r '.model.display_name // .model // "unknown"')

# Don't show anything for 0%
if (( $(echo "$USED_PCT == 0" | bc -l) )); then
  exit 0
fi

# Build progress bar (20 squares total, each full = 5%, half = 2.5%)
FULL_SQUARES=$(echo "scale=0; $USED_PCT / 5" | bc)
REMAINDER=$(echo "scale=1; $USED_PCT - ($FULL_SQUARES * 5)" | bc)
HAS_HALF=$(echo "$REMAINDER >= 2.5" | bc -l)

BAR=""
for ((i=0; i<FULL_SQUARES; i++)); do
  BAR+="■"
done
if [ "$HAS_HALF" -eq 1 ]; then
  BAR+="◧"
  EMPTY_SQUARES=$((20 - FULL_SQUARES - 1))
else
  EMPTY_SQUARES=$((20 - FULL_SQUARES))
fi
for ((i=0; i<EMPTY_SQUARES; i++)); do
  BAR+="□"
done

# Color based on usage (grey < 60%, orange 60-80%, red > 80%)
if (( $(echo "$USED_PCT < 60" | bc -l) )); then
  COLOR="\033[90m"  # Grey
elif (( $(echo "$USED_PCT < 80" | bc -l) )); then
  COLOR="\033[38;5;208m"  # Orange
else
  COLOR="\033[31m"  # Red
fi
RESET="\033[0m"

# Output: opus 4.5 | context: ■■■■■■◧□□□□□□□□□□□□□ 62%
printf "%s | ctx ${COLOR}%s %.0f%%${RESET}" "$MODEL" "$BAR" "$USED_PCT"
