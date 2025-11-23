#!/usr/bin/env bash

# Remote install script for dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/tyom/dotfiles/master/install.sh | bash
#
# Use `make install` to install locally from a cloned repository

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="https://github.com/tyom/dotfiles"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-master}"

echo "Installing dotfiles to $DOTFILES_DIR..."

# Check for required tools
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required but not installed."
  echo "Install curl and try again, or clone the repository manually."
  exit 1
fi

# Download and extract dotfiles
if command -v git >/dev/null 2>&1; then
  # Prefer git clone for easier updates
  if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "Dotfiles already cloned. Pulling latest changes..."
    git -C "$DOTFILES_DIR" pull
  else
    echo "Cloning dotfiles repository..."
    rm -rf "$DOTFILES_DIR"
    git clone --depth 1 -b "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
else
  # Fallback to curl + tar
  echo "Git not found. Downloading tarball..."
  mkdir -p "$DOTFILES_DIR"
  curl -fsSL "$DOTFILES_REPO/tarball/$DOTFILES_BRANCH" | tar -xz -C "$DOTFILES_DIR" --strip-components=1
fi

# Run setup (includes validation)
cd "$DOTFILES_DIR"
./scripts/setup.sh
