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

printf 'user memory\n' >"$user/CLAUDE.md"

# The repo: a memory file importing a second one, its own skill, its own server
printf '@../shared/AGENTS.md\n\nproject memory\n' >"$TMP/repo/CLAUDE.md"
printf 'shared instructions\n' >"$TMP/shared/AGENTS.md"
skill "$TMP/repo/.claude/skills/proj" proj
printf '{ "mcpServers": { "repo-server": { "command": "true" } } }\n' >"$TMP/repo/.mcp.json"

run() { (cd "$TMP/repo" && HOME="$TMP/home" "$ROOT/home/bin/agent-ctx" "$@" | sed 's/\x1b\[[0-9;]*m//g'); }

# The same repo seen by Codex: TOML config, its own memory file and plugin layout
codex="$TMP/home/.codex"
mkdir -p "$codex/plugins/cache/store/gamma/9f3c" "$codex/plugins/cache/store/delta/1a2b" \
  "$codex/plugins/cache/gone/epsilon/7b8d"
printf 'codex memory\n' >"$codex/AGENTS.md"
printf 'repo memory for codex\n' >"$TMP/repo/AGENTS.md"
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

# The description is the only part of a skill that ships every session
desc_bytes=$(printf 'description: %s\n%s\n' "$desc_line1" "$desc_line2" | wc -c)
skill_bytes=$(cat "$TMP/repo/.claude/skills/proj/SKILL.md" | wc -c)
always=$((desc_bytes / 3))
on_trigger=$((skill_bytes / 3 - always))

if ! grep -qE "^  project skills +$always +$on_trigger +- +1$" <<<"$output"; then
  fail "project skills should be $always always and $on_trigger on trigger"
fi

memory_bytes=$(cat "$TMP/repo/CLAUDE.md" | wc -c)
if ! grep -qE "^  CLAUDE.md +$((memory_bytes / 3)) +- +- +-$" <<<"$output"; then
  fail "the repo CLAUDE.md should be counted in full"
fi

grep -q 'shared/AGENTS.md' <<<"$output" || fail 'an @import in a memory file should be followed'

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

# The skill carrying references is the heavier one to open
output=$(run alpha)
if [ "$(grep -c '^  ' <<<"$output")" -ne 2 ] || [[ "$(grep '^  ' <<<"$output" | head -1)" != *one* ]]; then
  fail 'drilling into a group should list its skills, heaviest to open first'
fi

output=$(run -a codex)

grep -qE '^  AGENTS.md ' <<<"$output" || fail 'codex should count the repo AGENTS.md'
grep -q 'CLAUDE.md' <<<"$output" && fail 'codex does not read CLAUDE.md'
grep -q 'plugin gamma skills' <<<"$output" || fail 'an enabled codex plugin should be counted'
grep -q 'plugin delta' <<<"$output" && fail 'a codex plugin disabled in config.toml should not be counted'
grep -q 'plugin epsilon' <<<"$output" &&
  fail 'a codex plugin whose marketplace is no longer registered should not be counted'
grep -qE 'mcp servers|live' <<<"$output" || fail 'a server in config.toml should be named'
grep -q 'parked' <<<"$output" && fail 'a server disabled in config.toml should not be named'
grep -q 'live.env' <<<"$output" && fail 'a nested TOML table is not a server'

# Without -a, a line for each harness installed and neither one's table
output=$(run)
grep -qE '^  claude ' <<<"$output" || fail 'the summary should carry a claude row'
grep -qE '^  codex ' <<<"$output" || fail 'the summary should carry a codex row'
grep -q 'plugin alpha' <<<"$output" && fail 'the summary should not open a table'

echo " ✔ agent-ctx reports what each directory puts in context, for claude and codex"
