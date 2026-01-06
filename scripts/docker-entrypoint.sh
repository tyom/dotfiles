#!/bin/bash

# Docker entrypoint for dotfiles testing
# Usage:
#   docker run <image>               # Interactive shell (no setup)
#   docker run <image> setup         # Run setup, then shell
#   docker run <image> setup-minimal # Run setup without Homebrew/Bun, then shell
#   docker run <image> validate      # Run validation only
#   docker run <image> test          # Run setup + validation
#   docker run <image> test-minimal  # Run minimal setup + validation

set -e

DOTFILES_DIR="$HOME/.dotfiles"
cd "$DOTFILES_DIR"

case "${1:-shell}" in
setup)
  if [ -f "$HOME/.dotfiles-setup-done" ]; then
    echo "Setup already complete. Starting shell..."
  else
    echo "Running dotfiles setup..."
    export YES_OVERRIDE=true
    ./scripts/setup.sh
    touch "$HOME/.dotfiles-setup-done"
    echo ""
    echo "Setup complete. Starting shell..."
  fi
  exec zsh
  ;;
setup-minimal)
  if [ -f "$HOME/.dotfiles-setup-done" ]; then
    echo "Setup already complete. Starting shell..."
  else
    echo "Running minimal dotfiles setup (no Homebrew/Bun)..."
    export YES_OVERRIDE=true
    export MINIMAL_SETUP=true
    ./scripts/setup.sh
    touch "$HOME/.dotfiles-setup-done"
    echo ""
    echo "Setup complete. Starting shell..."
  fi
  exec zsh
  ;;
validate)
  echo "Running validation..."
  ./scripts/validate.sh
  ;;
test)
  echo "Running setup (includes validation)..."
  export YES_OVERRIDE=true
  ./scripts/setup.sh
  ;;
test-minimal)
  echo "Running minimal setup (includes validation)..."
  export YES_OVERRIDE=true
  export MINIMAL_SETUP=true
  ./scripts/setup.sh
  ;;
shell)
  exec zsh
  ;;
*)
  # Pass through any other command
  exec "$@"
  ;;
esac
