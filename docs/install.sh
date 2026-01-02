#!/usr/bin/env bash

# Dotfiles install script
#
# Remote install (clones to ~/.dotfiles):
#   curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
#
# Remote install to custom location:
#   DOTFILES_DIR=~/Code/dotfiles curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
#
# Non-interactive (skip prompts during setup):
#   curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash -s -- -y
#
# Local install (from existing repo):
#   ./docs/install.sh
#   # or: make install

set -e

DOTFILES_REPO="https://github.com/tyom/dotfiles"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-master}"
YES_OVERRIDE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes) YES_OVERRIDE=true; shift ;;
    *) shift ;;
  esac
done

# Export for setup.sh to use
export YES_OVERRIDE

# Detect if running from within an existing dotfiles repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../scripts/setup.sh" ]; then
  # Running from cloned repo (e.g., ./docs/install.sh or piped but repo exists)
  DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  echo "Using existing dotfiles at $DOTFILES_DIR"
elif [ -f "$SCRIPT_DIR/scripts/setup.sh" ]; then
  # Running from repo root
  DOTFILES_DIR="$SCRIPT_DIR"
  echo "Using existing dotfiles at $DOTFILES_DIR"
else
  # Remote install - clone to default location
  DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
  echo "Installing dotfiles to $DOTFILES_DIR..."

  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required but not installed."
    exit 1
  fi

  if command -v git >/dev/null 2>&1; then
    if [ -d "$DOTFILES_DIR/.git" ]; then
      echo "Dotfiles already cloned. Pulling latest changes..."
      git -C "$DOTFILES_DIR" pull
    else
      echo "Cloning dotfiles repository..."
      rm -rf "$DOTFILES_DIR"
      git clone --depth 1 -b "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
  else
    echo "Git not found. Downloading tarball..."
    mkdir -p "$DOTFILES_DIR"
    curl -fsSL "$DOTFILES_REPO/tarball/$DOTFILES_BRANCH" | tar -xz -C "$DOTFILES_DIR" --strip-components=1
  fi
fi

# Run setup
cd "$DOTFILES_DIR"
./scripts/setup.sh
