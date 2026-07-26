#!/bin/bash

# Check that a file already sitting at a stow target doesn't block the install.
# Runs against a throwaway HOME, so it never touches the real one.

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DOTFILES_DIR
FAILED=0

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
  elif [ -f "$1" ]; then echo file
  else echo missing
  fi
}

# An empty file is taken over, so the install completes
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME" "$FAKE_HOME2" "$FAKE_HOME3"' EXIT
mkdir -p "$FAKE_HOME/.claude"
: >"$FAKE_HOME/.claude/CLAUDE.md"
HOME="$FAKE_HOME" bash "$DOTFILES_DIR/scripts/stow.sh" >/dev/null 2>&1
assert "empty CLAUDE.md is replaced by a link" "$(kind "$FAKE_HOME/.claude/CLAUDE.md")" symlink
assert "the rest still links" "$(kind "$FAKE_HOME/.vimrc")" symlink

# A skipped file keeps its contents and doesn't stop the other symlinks. This is
# the --ignore regex the skip branch builds, so a stow behaviour change fails here.
FAKE_HOME2=$(mktemp -d)
mkdir -p "$FAKE_HOME2/.claude"
echo 'my own notes' >"$FAKE_HOME2/.claude/CLAUDE.md"
stow -v --ignore='\.DS_Store' --ignore='CLAUDE\.md' \
  -d "$DOTFILES_DIR" -t "$FAKE_HOME2" stow >/dev/null 2>&1
assert "skipped CLAUDE.md stays a real file" "$(kind "$FAKE_HOME2/.claude/CLAUDE.md")" file
assert "skipped file keeps its contents" "$(cat "$FAKE_HOME2/.claude/CLAUDE.md")" 'my own notes'
assert "a skipped conflict doesn't block the rest" "$(kind "$FAKE_HOME2/.vimrc")" symlink

# Opting out of the agent instructions leaves ~/.claude and ~/.codex untouched
FAKE_HOME3=$(mktemp -d)
STOW_SKIP_AGENTS=true HOME="$FAKE_HOME3" bash "$DOTFILES_DIR/scripts/stow.sh" >/dev/null 2>&1
assert "CLAUDE.md is not linked when opted out" "$(kind "$FAKE_HOME3/.claude/CLAUDE.md")" missing
assert "AGENTS.md is not linked when opted out" "$(kind "$FAKE_HOME3/.codex/AGENTS.md")" missing
assert "everything else still links" "$(kind "$FAKE_HOME3/.vimrc")" symlink

# Opting out afterwards leaves links that are already there. Stow skips the
# file, it doesn't unlink it, so this is a skip and not an uninstall.
STOW_SKIP_AGENTS=true HOME="$FAKE_HOME" bash "$DOTFILES_DIR/scripts/stow.sh" >/dev/null 2>&1
assert "opting out keeps an existing CLAUDE.md link" "$(kind "$FAKE_HOME/.claude/CLAUDE.md")" symlink
assert "opting out keeps an existing AGENTS.md link" "$(kind "$FAKE_HOME/.codex/AGENTS.md")" symlink

exit $FAILED
