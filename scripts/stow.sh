#!/bin/bash

# Create symlinks using GNU Stow
# The stow/ directory mirrors the home directory structure

source "$DOTFILES_DIR/shell/utils.sh"

# Pre-create every directory that stow/ contains. Stow folds a whole directory
# into one symlink when the target doesn't exist yet, so without this, ~/.config
# would become a link into this repo and every tool's config would land in the
# working tree. One line per directory added under stow/.
mkdir -p "$HOME/bin" "$HOME/.config/ghostty"

# Use system stow on Linux (Homebrew stow has Perl dependency issues)
if [[ "$(uname)" == "Linux" ]] && [[ -x /usr/bin/stow ]]; then
  STOW_CMD="/usr/bin/stow"
else
  STOW_CMD="stow"
fi

# Warn about conflicting files (we don't delete user files)
STOW_DIR="$DOTFILES_DIR/stow"
find "$STOW_DIR" -type f ! -name .DS_Store | while read -r file; do
  rel_path="${file#$STOW_DIR/}"
  target="$HOME/$rel_path"
  if [ -f "$target" ] && [ ! -L "$target" ]; then
    # stow aborts every operation on a single conflict, not just this one
    print_warning "Existing file will block ALL symlinks until moved: $target"
  fi
done

# Stow the entire stow/ directory
STOW_OUTPUT=$($STOW_CMD -v --ignore='\.DS_Store' -d "$DOTFILES_DIR" -t "$HOME" stow 2>&1)
STOW_EXIT=$?
echo "$STOW_OUTPUT" | grep -v "^BUG" || true
if [ $STOW_EXIT -ne 0 ]; then
  print_error "Stow failed. Check conflicts above and resolve manually."
  exit 1
fi

print_success "Symlinks created via Stow"
