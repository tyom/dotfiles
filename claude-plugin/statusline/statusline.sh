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

# Auto-compact threshold is 77.5% (22.5% buffer)
# Calculate effective percentage against the 77.5% threshold
EFFECTIVE_PCT=$(echo "scale=2; $USED_PCT / 77.5 * 100" | bc -l)
if (( $(echo "$EFFECTIVE_PCT > 100" | bc -l) )); then
  EFFECTIVE_PCT=100
fi

# Clamp raw percentage to 0-77.5 range (usable portion)
CLAMPED_PCT=$(echo "if ($USED_PCT < 0) 0 else if ($USED_PCT > 77.5) 77.5 else $USED_PCT" | bc -l)

# Build progress bar: 15 usable squares (75%) + 5 reserved squares (25%)
# Each square = 5% of total context
FULL_SQUARES=$(echo "scale=0; $CLAMPED_PCT / 5" | bc)
if [ "$FULL_SQUARES" -gt 15 ]; then
  FULL_SQUARES=15
fi

REMAINDER=$(echo "scale=1; $CLAMPED_PCT - ($FULL_SQUARES * 5)" | bc)
if [ "$FULL_SQUARES" -lt 15 ] && (( $(echo "$REMAINDER >= 2.5" | bc -l) )); then
  HAS_HALF=1
else
  HAS_HALF=0
fi

HALF_COUNT=$((HAS_HALF))
EMPTY_SQUARES=$((15 - FULL_SQUARES - HALF_COUNT))
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

# Color based on effective usage (grey < 75%, orange 75-94%, red >= 94%)
# These thresholds correspond to 60%/75%/80% of total context
if (( $(echo "$EFFECTIVE_PCT < 75" | bc -l) )); then
  COLOR="\033[90m"  # Grey
elif (( $(echo "$EFFECTIVE_PCT < 94" | bc -l) )); then
  COLOR="\033[38;5;208m"  # Orange (75% effective = 60% total)
else
  COLOR="\033[31m"  # Red (94% effective ≈ 75% total, near limit)
fi
RESET="\033[0m"
DARK_GRAY="\033[38;5;240m"  # Dark gray for reserved blocks

# Output: Opus 4.5 | ctx ■■■■■■■■■■■■■■□▨▨▨▨▨ 89%
printf "%s | ctx ${COLOR}%s${DARK_GRAY}▨▨▨▨▨${COLOR} %.0f%%${RESET}" "$MODEL" "$BAR" "$EFFECTIVE_PCT"
