#!/usr/bin/env bash

# Dotfiles install script
#
# Remote install (clones to ~/.dotfiles):
#   curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
#
# Remote install to custom location:
#   curl -fsSL https://tyom.github.io/dotfiles/install.sh | DOTFILES_DIR=~/Code/dotfiles bash
#
# Non-interactive (skip prompts during setup):
#   curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash -s -- -y
#
# Non-interactive, picking what to install:
#   curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash -s -- --select dotfiles,brew
#
# Local install (from existing repo):
#   ./docs/install.sh
#   # or: make install

set -e

DOTFILES_REPO="https://github.com/tyom/dotfiles"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-master}"

# Every option belongs to setup.sh, so they are forwarded verbatim rather than
# re-parsed here. Parsing -y into an exported YES_OVERRIDE used to also overwrite
# one the caller had exported, which is how a CI run asking for everything got
# the interactive defaults instead.
SETUP_ARGS=("$@")

is_dotfiles_checkout() {
  [ -x "$1/scripts/setup.sh" ] || return 1

  local remote
  remote=$(git -C "$1" remote get-url origin 2>/dev/null) || return 1
  case "$remote" in
  "$DOTFILES_REPO" | "$DOTFILES_REPO.git" | \
    git@github.com:tyom/dotfiles | git@github.com:tyom/dotfiles.git | \
    ssh://git@github.com/tyom/dotfiles | ssh://git@github.com/tyom/dotfiles.git) return 0 ;;
  *) return 1 ;;
  esac
}

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
      if ! is_dotfiles_checkout "$DOTFILES_DIR"; then
        echo "Error: $DOTFILES_DIR is a Git checkout, but not this dotfiles repository."
        exit 1
      fi
      echo "Dotfiles already cloned. Pulling latest changes..."
      git -C "$DOTFILES_DIR" pull
    else
      if [ -d "$DOTFILES_DIR" ] && [ -n "$(ls -A "$DOTFILES_DIR")" ]; then
        echo "Error: $DOTFILES_DIR exists and is not a dotfiles clone. Remove it or set DOTFILES_DIR elsewhere."
        exit 1
      fi
      echo "Cloning dotfiles repository..."
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
./scripts/setup.sh "${SETUP_ARGS[@]}"
