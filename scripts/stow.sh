#!/bin/bash

# Create symlinks using GNU Stow
# Each package directory mirrors the home directory structure

source "$DOTFILES_DIR/scripts/vars"
source "$DOTFILES_DIR/shell/utils"

# Ensure ~/bin exists for the bin package
mkdir -p "$HOME/bin"

# Use system stow on Linux (Homebrew stow has Perl dependency issues)
# On macOS, use Homebrew stow
if [[ "$(uname)" == "Linux" ]] && [[ -x /usr/bin/stow ]]; then
  STOW_CMD="/usr/bin/stow"
else
  STOW_CMD="stow"
fi

# Remove conflicting files before stowing (backup handled separately)
# This ensures our dotfiles take precedence over installer-generated files
remove_conflicts() {
  local package="$1"
  local package_dir="$DOTFILES_DIR/$package"

  # Find all files in the package and remove corresponding files in home
  find "$package_dir" -type f -name ".*" ! -name ".stow-local-ignore" | while read -r file; do
    local rel_path="${file#$package_dir/}"
    local target="$HOME/$rel_path"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      echo "   Removing conflicting file: $target"
      rm -f "$target"
    fi
  done
}

# Stow each package
for package in "${STOW_PACKAGES[@]}"; do
  if [ -d "$DOTFILES_DIR/$package" ]; then
    echo "   Stowing $package..."
    remove_conflicts "$package"
    $STOW_CMD -v -d "$DOTFILES_DIR" -t "$HOME" "$package" 2>&1 | grep -v "^BUG" || true
  else
    print_error "Package directory not found: $package"
  fi
done

print_success "Symlinks created via Stow"
