#!/bin/bash

# Status line: model, context usage, and the workspace git branch.
# Output: Opus 5 | 14.52k ████████▌ 89% | ⎇ master
#
# This runs on every render, so it makes three calls and no more: jq to read the
# payload, git for the branch, awk to lay out the line. The version it replaced
# spent ~46ms on four jq passes over the same stdin plus bc and awk for
# arithmetic. The float work stays in awk rather than moving to bash integers —
# printf's rounding is the reference here, and reimplementing it is more code
# for a result that is only ever equal at best.

# Requires: jq
if ! command -v jq &>/dev/null; then
  echo "statusline: jq required" >&2
  exit 1
fi

# One pass: model, summed tokens, raw percentage, and the directory to read the
# branch from. Tab-separated because a model display name can contain spaces.
#
# `.model` is an object in current payloads but has been a bare string, so it is
# type-tested rather than indexed — indexing a string is a hard jq error, and
# with one shared call that would take every other field down with it.
IFS=$'\t' read -r MODEL USED_TOKENS USED_PCT DIR < <(jq -r '
  (.context_window.current_usage // {}) as $u
  | [ ((.model | if type == "object" then .display_name else . end) // "unknown"),
      (($u.input_tokens // 0) + ($u.output_tokens // 0)
       + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)),
      (.context_window.used_percentage // 0),
      (.workspace.current_dir // .cwd // "")
    ] | @tsv' 2>/dev/null)

# Malformed input leaves these empty; fall back rather than feed awk blanks.
: "${MODEL:=unknown}" "${USED_TOKENS:=0}" "${USED_PCT:=0}"

# Git branch of the workspace dir. Passed to awk as data, never as part of a
# format string, so a branch name cannot corrupt the output.
BRANCH=$(git -C "${DIR:-.}" branch --show-current 2>/dev/null)

awk -v model="$MODEL" -v tokens="$USED_TOKENS" -v raw_pct="$USED_PCT" \
  -v branch="$BRANCH" '
BEGIN {
  # Dimmed, and built here rather than in a printf subshell — that was a fourth
  # process on a line that renders several times a second.
  if (branch != "") branch = " | \033[38;5;244m⎇ " branch "\033[0m"

  # Before the first response there is no usage yet — model and branch only. A
  # negative percentage is garbage rather than "nothing yet", so it still draws.
  if (raw_pct == 0) { printf "%s%s", model, branch; exit }

  pct = raw_pct < 0 ? 0 : (raw_pct > 100 ? 100 : raw_pct)

  # Bar: 10 cells spanning 0-100%, each cell 10%, a half block at 5% or more.
  full = int(pct / 10); if (full > 10) full = 10
  half = (full < 10 && pct - full * 10 >= 5) ? 1 : 0
  empty = 10 - full - half; if (empty < 0) empty = 0
  for (i = 0; i < full; i++) bar = bar "█"
  if (half) bar = bar "▌"
  for (i = 0; i < empty; i++) bar = bar " "

  if (tokens >= 1000000) label = sprintf("%.2fM", tokens / 1000000)
  else if (tokens >= 1000) label = sprintf("%.2fk", tokens / 1000)
  else label = sprintf("%d", tokens)

  # Token count and bar share one colour, by absolute usage:
  # green ≤100k, yellow 100k-600k, red >600k
  color = tokens <= 100000 ? "\033[32m" : (tokens <= 600000 ? "\033[33m" : "\033[31m")

  # Cells sit on a dim background so the half block ▌ has no gap on its right
  printf "%s | %s%s\033[0m %s\033[48;5;236m%s\033[0m%s %.0f%%\033[0m%s", \
    model, color, label, color, bar, color, pct, branch
}'
