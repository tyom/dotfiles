#!/bin/bash

# Exercise agent-ctx against a throwaway HOME and repo, with every expected
# number worked out from the fixture rather than from the tool.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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
mkdir -p "$codex/plugins/cache/store/gamma/9f3c" "$codex/plugins/cache/store/delta/1a2b"
printf 'codex memory\n' >"$codex/AGENTS.md"
printf 'repo memory for codex\n' >"$TMP/repo/AGENTS.md"
skill "$codex/skills/local" local
skill "$codex/plugins/cache/store/gamma/9f3c/skills/from-plugin" from-plugin
skill "$codex/plugins/cache/store/delta/1a2b/skills/off" off
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
TOML


output=$(run)

# The description is the only part of a skill that ships every session
desc_bytes=$(printf 'description: %s\n%s\n' "$desc_line1" "$desc_line2" | wc -c)
skill_bytes=$(cat "$TMP/repo/.claude/skills/proj/SKILL.md" | wc -c)
always=$((desc_bytes / 4))
on_demand=$((skill_bytes / 4 - always))

if ! grep -qE "^  project skills +$always +$on_demand +1$" <<<"$output"; then
  fail "project skills should be $always always and $on_demand on demand"
fi

memory_bytes=$(cat "$TMP/repo/CLAUDE.md" | wc -c)
if ! grep -qE "^  CLAUDE.md +$((memory_bytes / 4)) +- +-$" <<<"$output"; then
  fail "the repo CLAUDE.md should be counted in full"
fi

grep -q 'shared/AGENTS.md' <<<"$output" || fail 'an @import in a memory file should be followed'

# The stale cached version and the disabled plugin are not in play
grep -q '1.0.0' <<<"$output" && fail 'a stale plugin version in the cache should not be counted'
grep -q 'plugin beta' <<<"$output" && fail 'a plugin disabled in settings should not be counted'

# Two skills, and the loose file beside them is not a third
if ! grep -qE "^  plugin alpha skills +$((always * 2)) +[0-9,]+ +2$" <<<"$output"; then
  fail 'the installed plugin should show its two skills and their descriptions'
fi

grep -q 'Stop' <<<"$output" || fail 'a hook in settings should be listed by its event'
grep -q 'repo-server' <<<"$output" || fail 'a server in the repo .mcp.json should be named'

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
grep -qE 'mcp servers|live' <<<"$output" || fail 'a server in config.toml should be named'
grep -q 'parked' <<<"$output" && fail 'a server disabled in config.toml should not be named'
grep -q 'live.env' <<<"$output" && fail 'a nested TOML table is not a server'

echo " ✔ agent-ctx reports what each directory puts in context, for claude and codex"
