#!/bin/bash

# Check the conflict handling in link.sh and unlink.sh against a throwaway HOME,
# so it never touches the real one.

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DOTFILES_DIR
FAILED=0

# One parent so the trap cleans up every fake home with a single rm
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

assert() {
  if [ "$2" = "$3" ]; then
    printf ' ✔ %s\n' "$1"
  else
    printf ' ✖ %s (expected %s, got %s)\n' "$1" "$3" "$2"
    FAILED=1
  fi
}

kind() {
  if [ -L "$1" ]; then echo symlink
  elif [ -d "$1" ]; then echo dir
  elif [ -f "$1" ]; then echo file
  else echo missing
  fi
}

fake_home() {
  mkdir -p "$TMP/$1"
  echo "$TMP/$1"
}

link() { HOME="$1" bash "$DOTFILES_DIR/scripts/link.sh" >/dev/null 2>&1; }

# An empty file is taken over, so the install completes
H1=$(fake_home h1)
mkdir -p "$H1/.claude"
: >"$H1/.claude/CLAUDE.md"
link "$H1"
assert "empty CLAUDE.md is replaced by a link" "$(kind "$H1/.claude/CLAUDE.md")" symlink
assert "the rest still links" "$(kind "$H1/.vimrc")" symlink

# A conflict the prompts can't speak to is left alone and doesn't stop the rest
H2=$(fake_home h2)
mkdir -p "$H2/.vimrc"
echo 'mine' >"$H2/.vimrc/keep"
link "$H2"
assert "a directory at a target stays put" "$(kind "$H2/.vimrc")" dir
assert "its contents survive" "$(cat "$H2/.vimrc/keep")" mine
assert "and nothing is linked inside it" "$(kind "$H2/.vimrc/.vimrc")" missing
assert "a skipped conflict doesn't block the rest" "$(kind "$H2/.vimrc.bundles")" symlink

# A link left dangling by an earlier install is refreshed rather than skipped
H3=$(fake_home h3)
ln -s "$DOTFILES_DIR/gone/.vimrc" "$H3/.vimrc"
link "$H3"
assert "a dangling link is repointed" "$(cat "$H3/.vimrc")" "$(cat "$DOTFILES_DIR/home/.vimrc")"

# A link the user made elsewhere is not ours to take over
H4=$(fake_home h4)
echo 'not yours' >"$H4/elsewhere"
ln -s "$H4/elsewhere" "$H4/.vimrc"
link "$H4"
assert "a foreign link is left alone" "$(cat "$H4/.vimrc")" 'not yours'

# Opting out of the agent instructions leaves ~/.claude and ~/.codex untouched
H5=$(fake_home h5)
SKIP_AGENTS=true link "$H5"
assert "CLAUDE.md is not linked when opted out" "$(kind "$H5/.claude/CLAUDE.md")" missing
assert "AGENTS.md is not linked when opted out" "$(kind "$H5/.codex/AGENTS.md")" missing
assert "the codex skill link is not made when opted out" "$(kind "$H5/.codex/skills/simplify")" missing
assert "everything else still links" "$(kind "$H5/.vimrc")" symlink

# Opting out afterwards is a skip, not an uninstall: existing links stay
SKIP_AGENTS=true link "$H1"
assert "opting out keeps an existing CLAUDE.md link" "$(kind "$H1/.claude/CLAUDE.md")" symlink
assert "opting out keeps an existing AGENTS.md link" "$(kind "$H1/.codex/AGENTS.md")" symlink
assert "opting out keeps an existing codex skill link" "$(readlink "$H1/.codex/skills/simplify")" "$DOTFILES_DIR/home/.agents/skills/simplify"

# ln -sfn would delete a real file at the codex skill target, so it is left alone
H6=$(fake_home h6)
mkdir -p "$H6/.codex/skills"
echo 'mine' >"$H6/.codex/skills/simplify"
link "$H6"
assert "a file at the codex skill target stays a file" "$(kind "$H6/.codex/skills/simplify")" file
assert "and its contents survive" "$(cat "$H6/.codex/skills/simplify")" mine

# Codex reads only its own skills dir, so the shared skills are linked there too
assert "the codex skill is linked" "$(kind "$H4/.codex/skills/simplify")" symlink
assert "and reads through to the repo" "$(kind "$H4/.codex/skills/simplify/SKILL.md")" file

# unlink takes back its own links and leaves the user's alone
HOME="$H4" bash "$DOTFILES_DIR/scripts/unlink.sh" >/dev/null 2>&1
assert "unlink removes our links" "$(kind "$H4/.vimrc.bundles")" missing
assert "unlink removes the codex skill link" "$(kind "$H4/.codex/skills/simplify")" missing
assert "unlink clears the directories it made" "$(kind "$H4/bin")" missing
assert "including nested ones" "$(kind "$H4/.config")" missing
assert "unlink leaves a foreign link alone" "$(cat "$H4/.vimrc")" 'not yours'

exit $FAILED
