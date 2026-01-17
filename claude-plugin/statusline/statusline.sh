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

# Clamp percentage to 0-100 range
CLAMPED_PCT=$(echo "if ($USED_PCT < 0) 0 else if ($USED_PCT > 100) 100 else $USED_PCT" | bc -l)

# Build progress bar (20 squares total, each full = 5%, half = 2.5%)
FULL_SQUARES=$(echo "scale=0; $CLAMPED_PCT / 5" | bc)
if [ "$FULL_SQUARES" -gt 20 ]; then
  FULL_SQUARES=20
fi

REMAINDER=$(echo "scale=1; $CLAMPED_PCT - ($FULL_SQUARES * 5)" | bc)
if [ "$FULL_SQUARES" -lt 20 ] && (( $(echo "$REMAINDER >= 2.5" | bc -l) )); then
  HAS_HALF=1
else
  HAS_HALF=0
fi

HALF_COUNT=$((HAS_HALF))
EMPTY_SQUARES=$((20 - FULL_SQUARES - HALF_COUNT))
if [ "$EMPTY_SQUARES" -lt 0 ]; then
  EMPTY_SQUARES=0
fi

BAR=""
for ((i=0; i<FULL_SQUARES; i++)); do
  BAR+="■"
done
if [ "$HAS_HALF" -eq 1 ]; then
  BAR+="◧"
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
