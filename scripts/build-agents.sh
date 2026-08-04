#!/bin/bash

# Build the agent instruction files from src/agents/.
# Each agent template is copied with its `@common` line replaced by
# src/agents/common.md, so shared rules are written once. The result lands in
# home/ because the installer needs a real file to symlink.

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$DOTFILES_DIR"

build() { # $1 = template, $2 = output
  mkdir -p "$(dirname "$2")"
  sed -e '/^@common$/r src/agents/common.md' -e '/^@common$/d' "$1" >"$2"

  # Fails loudly if sed stops expanding the marker, rather than shipping a file
  # that tells the agent to read a line it cannot see.
  if grep -q '^@common$' "$2" || ! grep -q '^## Communication$' "$2"; then
    echo "build-agents: $1 did not expand @common" >&2
    exit 1
  fi
}

# The templates are named *.tmpl.md so that an agent scanning this repo does not
# mistake src/agents/claude.md for a CLAUDE.md of its own (macOS ignores case).
build src/agents/claude.tmpl.md home/.claude/CLAUDE.md
build src/agents/codex.tmpl.md home/.codex/AGENTS.md
