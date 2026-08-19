#!/bin/bash

# Exercise agent-ctx against a throwaway HOME and repo, with every expected
# number worked out from the fixture rather than from the tool.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# agent-ctx exits early without jq, and every assertion below would then fail
# with a wrong number rather than the reason
command -v jq >/dev/null || {
  echo " ✖ agent-ctx needs jq, which is not on PATH"
  exit 1
}

fail() {
  echo " ✖ $1"
  echo "$output" | sed 's/\x1b\[[0-9;]*m//g'
  exit 1
}

user="$TMP/home/.claude"
cache="$user/plugins/cache/market"
mkdir -p "$user/plugins" "$TMP/shared" "$TMP/repo/.claude/skills/proj"

# A description that wraps onto a second line, above a body containing the same
# --- that closes frontmatter
desc_line1='Does a thing. Use when the user asks for a thing, or mentions'
desc_line2='  anything nearby, which happens a lot.'
skill() { # dir name
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: %s\n%s\nallowed-tools: Read\n---\n\n# %s\n\n---\n\nbody\n' \
    "$2" "$desc_line1" "$desc_line2" "$2" >"$1/SKILL.md"
}

# The installed plugin, one of its skills carrying a references directory
skill "$cache/alpha/2.0.0/skills/one" one
# skills are often symlinked in from where they are really kept
skill "$TMP/elsewhere/two" two
ln -s "$TMP/elsewhere/two" "$cache/alpha/2.0.0/skills/two"
mkdir -p "$cache/alpha/2.0.0/skills/one/references"
# frontmatter here is never in context, only the skill's own SKILL.md counts
{
  printf -- '---\ndescription: %s\n---\n' "$desc_line1"
  head -c 4000 /dev/zero | tr '\0' 'x'
} >"$cache/alpha/2.0.0/skills/one/references/big.md"
printf '{ "synced": true }\n' >"$cache/alpha/2.0.0/skills/.sync-manifest"

# A stale copy left behind in the cache, and a plugin turned off in settings
skill "$cache/alpha/1.0.0/skills/stale" stale
skill "$cache/beta/1.0.0/skills/switched-off" switched-off

cat >"$user/plugins/installed_plugins.json" <<JSON
{ "plugins": {
  "alpha@market": [ { "installPath": "$cache/alpha/2.0.0" } ],
  "beta@market": [ { "installPath": "$cache/beta/1.0.0" } ]
} }
JSON

cat >"$user/settings.json" <<'JSON'
{
  "enabledPlugins": { "alpha@market": true, "beta@market": false },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "echo {}" } ] } ] }
}
JSON

printf '@../../shared/AGENTS.md\nuser memory\n' >"$user/CLAUDE.md"

# The repo: a memory file importing others, its own skill, its own server
# shellcheck disable=SC2016 # Markdown backticks and @paths are literal fixtures
printf '@../shared/AGENTS.md\n@../shared/hop1.md\nRead @../shared/inline.md for details.\nKeep `@../shared/inline-code.md` literal.\n```text\n@../shared/fenced.md\n```\n\nproject memory\n' >"$TMP/repo/CLAUDE.md"
printf 'project dot-claude memory\n' >"$TMP/repo/.claude/CLAUDE.md"
memory_fixture=$'---\nname: memory\n---\n<!-- hidden -->\nvisible memory\n'
printf '%s' "$memory_fixture" >"$TMP/shared/AGENTS.md"
printf 'inline import\n' >"$TMP/shared/inline.md"
printf 'inline code literal\n' >"$TMP/shared/inline-code.md"
printf 'fenced literal\n' >"$TMP/shared/fenced.md"
printf '@hop2.md\nhop one\n' >"$TMP/shared/hop1.md"
printf '@hop3.md\nhop two\n' >"$TMP/shared/hop2.md"
printf '@hop4.md\nhop three\n' >"$TMP/shared/hop3.md"
printf '@hop5.md\nhop four\n' >"$TMP/shared/hop4.md"
printf 'hop five\n' >"$TMP/shared/hop5.md"
skill "$TMP/repo/.claude/skills/proj" proj
mkdir -p "$TMP/repo/.claude/skills/hidden"
printf -- '---\nname: hidden\ndescription: %s\n%s\ndisable-model-invocation: true\n---\n\n# hidden\n' \
  "$desc_line1" "$desc_line2" >"$TMP/repo/.claude/skills/hidden/SKILL.md"
printf '{ "mcpServers": { "repo-server": { "command": "true" } } }\n' >"$TMP/repo/.mcp.json"

run() { (cd "$TMP/repo" && HOME="$TMP/home" "$ROOT/home/bin/agent-ctx" "$@" | sed 's/\x1b\[[0-9;]*m//g'); }

# The same repo seen by Codex: TOML config, its own memory file and plugin layout
codex="$TMP/home/.codex"
mkdir -p "$codex/plugins/cache/store/gamma/9f3c" "$codex/plugins/cache/store/delta/1a2b" \
  "$codex/plugins/cache/gone/epsilon/7b8d"
printf '%s' "$memory_fixture" >"$codex/AGENTS.md"
printf '%s' "$memory_fixture" >"$TMP/repo/AGENTS.md"
printf 'repo override for codex\n' >"$TMP/repo/AGENTS.override.md"
skill "$codex/skills/local" local
skill "$codex/plugins/cache/store/gamma/9f3c/skills/from-plugin" from-plugin
skill "$codex/plugins/cache/store/delta/1a2b/skills/off" off
skill "$codex/plugins/cache/gone/epsilon/7b8d/skills/orphaned" orphaned
cat >"$codex/config.toml" <<'TOML'
model = "gpt-5.6-sol"

[mcp_servers.live]
command = "true"

[mcp_servers.live.env]
KEY = "value"

[mcp_servers.parked]
command = "true"
enabled = false

[plugins."gamma@store"]
enabled = true

[plugins."delta@store"]
enabled = false

# Enabled, unpacked, and from a marketplace that is no longer registered below,
# which is how a plugin stays on disk long after Codex stopped loading it
[plugins."epsilon@gone"]
enabled = true

[marketplaces.store]
source_type = "local"
source = "/dev/null"
TOML


output=$(run -a claude)
claude_output=$output

# A disabled skill is still available on demand, but its description is not in
# the listing sent every session
desc_bytes=$(printf 'description: %s\n%s\n' "$desc_line1" "$desc_line2" | wc -c)
always=$((desc_bytes / 3))

grep -qE "^  project skills +$always +[0-9,]+ +- +2$" <<<"$output" ||
  fail 'a skill disabled for model invocation should add no description to always'

memory_bytes=$(cat "$TMP/repo/CLAUDE.md" | wc -c)
if ! grep -qE "^  CLAUDE.md +$((memory_bytes / 3)) +- +- +-$" <<<"$output"; then
  fail "the repo CLAUDE.md should be counted in full"
fi

grep -q 'shared/AGENTS.md' <<<"$output" || fail 'an @import in a memory file should be followed'
[ "$(grep -c 'shared/AGENTS.md' <<<"$output")" -eq 1 ] ||
  fail 'the same memory file imported twice should only be counted once'
grep -q 'shared/inline.md' <<<"$output" || fail 'an inline @import should be followed'
grep -q 'inline-code.md' <<<"$output" && fail 'an @path in inline code should stay literal'
grep -q 'fenced.md' <<<"$output" && fail 'an @path in a fenced code block should stay literal'
grep -q 'shared/hop4.md' <<<"$output" || fail 'memory imports should be followed for four hops'
grep -q 'shared/hop5.md' <<<"$output" && fail 'memory imports should stop after four hops'
grep -qE '^  \.claude/CLAUDE\.md ' <<<"$output" || fail 'claude should read project memory from .claude'
grep -qE '^  AGENTS\.md ' <<<"$output" && fail 'claude should only read AGENTS.md through an @import'

# The stale cached version and the disabled plugin are not in play
grep -q '1.0.0' <<<"$output" && fail 'a stale plugin version in the cache should not be counted'
grep -q 'plugin beta' <<<"$output" && fail 'a plugin disabled in settings should not be counted'

# Two skills, and the loose file beside them is not a third
if ! grep -qE "^  plugin alpha skills +$((always * 2)) +[0-9,]+ +[0-9,]+ +2$" <<<"$output"; then
  fail 'the installed plugin should show its two skills and their descriptions'
fi

# Event and source, not just the event: they travel as one tab-separated line, so
# a separator that is not a real tab leaves the whole row in the event column
grep -qE '^  Stop +~/\.claude/settings\.json$' <<<"$output" ||
  fail 'a hook in settings should be listed by its event and the file it came from'
grep -q 'repo-server' <<<"$output" || fail 'a server in the repo .mcp.json should be named'

# The bar goes in the label column, so the totals row has to stay as wide as the
# rows above it. A block is three bytes, the easy way to knock the columns out
widths=$(sed 's/█/#/g; s/▌/+/g' <<<"$output" |
  awk '/^  (total|plugin alpha skills) / { print length($0) }' | sort -u)
[ "$(printf '%s\n' "$widths" | wc -l)" -eq 1 ] ||
  fail 'the totals row should be as wide as the rows above it'

# Ten cells over the window, clamped at both ends
grep -qE '^  total  #{10}  100% of 10' <<<"$(run -a claude -w 10 | sed 's/█/#/g')" ||
  fail 'a window smaller than the total should fill the bar'

# Claude reserves one percent of the window for skill and command descriptions,
# and never less than one token of it: a window too small to round up should
# tighten the cap rather than turn it off
grep -qE "^  ∟ $((always * 3)) in skill and command descriptions, capped at 1 by the listing budget$" <<<"$(run -a claude -w 10)" ||
  fail 'a window too small for one percent should still cap the listing'
grep -qE '^  total {14}0% of 9m' <<<"$(run -a claude -w 9m)" ||
  fail 'a window far larger than the total should leave the bar empty'
(cd "$TMP/repo" && HOME="$TMP/home" "$ROOT/home/bin/agent-ctx" -w 1.5m) >/dev/null 2>&1 &&
  fail 'a window that is not a token count should be rejected'

# A filtered group uses the same resident-first weight order as the verbose
# table: proj has a listed description, while hidden has none
output=$(run 'project skills')
[[ "$(grep '^  ' <<<"$output" | head -1)" == *proj* ]] ||
  fail 'a filtered group should order items by resident weight first'

# An item opened on its own: where it is, where a symlink really points, what it
# says about itself, and the files the on read number is a ceiling over
output=$(run two)
grep -qE '^  ~/\.claude/plugins/cache/market/alpha/2\.0\.0/skills/two -> .*/elsewhere/two$' <<<"$output" ||
  fail 'an opened item should give its path and follow a symlink to where it is kept'
grep -qE '^  name: two$' <<<"$output" || fail 'an opened item should print its frontmatter'
grep -q 'body' <<<"$output" && fail 'an opened item should not print its body'
grep -qE '^  file +tokens$' <<<"$output" &&
  fail 'an item that is one file should not list that file again'

# one carries a references directory, which is what its on read number is made of
output=$(run one)
grep -qE '^  references/big\.md +[0-9,]+$' <<<"$output" ||
  fail 'an opened item should list the files below it, heaviest first'
grep -qE '^  SKILL\.md +[0-9,]+$' <<<"$output" ||
  fail 'an opened item should list its own entry file'

# proj is an item, and part of the project skills group name. The item wins,
# because a group is still reachable by a longer part of its own name
grep -q '^proj this repo · project skills$' <<<"$(run proj)" ||
  fail 'an item named in full should open even when a group name contains it'
grep -q '^hidden this repo · project skills$' <<<"$(run hidde)" ||
  fail 'part of an item name should open it when it matches no group'
(cd "$TMP/repo" && HOME="$TMP/home" "$ROOT/home/bin/agent-ctx" nonesuch) >/dev/null 2>&1 &&
  fail 'a name that is neither a group nor an item should be rejected'

# shellcheck disable=SC2088 # a literal tilde in the output, not a path to expand
cache_dir='~/\.claude/plugins/cache/market/alpha/2\.0\.0/skills'
grep -qE "^  plugin alpha skills +[0-9,]+ +[0-9,]+ +[0-9,]+ +$cache_dir\$" <<<"$(run -a claude -v)" ||
  fail 'the verbose table should say which directory a group loads from'

output=$(run -a codex)

grep -qE '^  AGENTS\.override\.md +8 +- +- +-$' <<<"$output" ||
  fail 'codex should use AGENTS.override.md instead of AGENTS.md in one directory'
memory_costs=$(
  sed -nE 's/^  .*shared\/AGENTS\.md +([0-9]+).*/\1/p' <<<"$claude_output"
  sed -nE 's/^  ~\/\.codex\/AGENTS\.md +([0-9]+).*/\1/p' <<<"$output"
)
grep -qE $'^5\n17$' <<<"$memory_costs" ||
  fail 'claude should strip memory metadata and comments that codex keeps'
grep -q 'CLAUDE.md' <<<"$output" && fail 'codex does not read CLAUDE.md'
grep -q 'plugin gamma skills' <<<"$output" || fail 'an enabled codex plugin should be counted'
grep -q 'plugin delta' <<<"$output" && fail 'a codex plugin disabled in config.toml should not be counted'
grep -q 'plugin epsilon' <<<"$output" &&
  fail 'a codex plugin whose marketplace is no longer registered should not be counted'
grep -qE 'mcp servers|live' <<<"$output" || fail 'a server in config.toml should be named'
grep -q 'parked' <<<"$output" || fail 'a server disabled in config.toml should still be named'
# Named but dimmed, so the colour is the whole assertion and run() has stripped it
raw=$(cd "$TMP/repo" && HOME="$TMP/home" "$ROOT/home/bin/agent-ctx" -a codex)
grep -q $'\033\[90mparked' <<<"$raw" || fail 'a disabled server should be dimmed, not coloured like a live one'
grep -q $'\033\[36mlive' <<<"$raw" || fail 'a live server should keep its colour'
grep -q 'live.env' <<<"$output" && fail 'a nested TOML table is not a server'

# Without -a, a line for each harness installed and neither one's table
output=$(run)
grep -qE '^  claude ' <<<"$output" || fail 'the summary should carry a claude row'
grep -qE '^  codex ' <<<"$output" || fail 'the summary should carry a codex row'
grep -q 'plugin alpha' <<<"$output" && fail 'the summary should not open a table'

echo " ✔ agent-ctx reports what each directory puts in context, for claude and codex"
