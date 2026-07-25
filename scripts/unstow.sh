#!/bin/bash

# Remove symlinks using GNU Stow
# This cleanly removes all dotfile symlinks

source "$DOTFILES_DIR/scripts/vars.sh"
source "$DOTFILES_DIR/shell/utils.sh"

# Use system stow on Linux (Homebrew stow has Perl dependency issues)
# On macOS, use Homebrew stow
if [[ "$(uname)" == "Linux" ]] && [[ -x /usr/bin/stow ]]; then
  STOW_CMD="/usr/bin/stow"
else
  STOW_CMD="stow"
fi

print_step "Removing dotfile symlinks..."

# Capture first: piping straight into the formatter would report the
# formatter's status, so a failed unstow would still look like a success.
UNSTOW_OUTPUT=$($STOW_CMD -v --ignore='\.DS_Store' -d "$DOTFILES_DIR" -t "$HOME" -D stow 2>&1)
UNSTOW_EXIT=$?
print_stow_output <<<"$UNSTOW_OUTPUT"
if [ $UNSTOW_EXIT -ne 0 ]; then
  print_error "Stow failed to remove the symlinks."
  exit 1
fi

print_success "Symlinks removed"
