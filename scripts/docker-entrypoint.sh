#!/bin/bash

# Docker entrypoint for dotfiles testing
# Usage:
#   docker run <image>              # Interactive shell (no setup)
#   docker run <image> setup        # Run setup, then shell
#   docker run <image> validate     # Run validation only
#   docker run <image> test         # Run setup + validation

set -e

DOTFILES_DIR="$HOME/dotfiles"
cd "$DOTFILES_DIR"

case "${1:-shell}" in
setup)
  echo "Running dotfiles setup..."
  export YES_OVERRIDE=true
  ./scripts/setup.sh
  echo ""
  echo "Setup complete. Starting shell..."
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
shell)
  exec zsh
  ;;
*)
  # Pass through any other command
  exec "$@"
  ;;
esac
