#!/bin/bash

# Create symlinks using GNU Stow
# Each package directory mirrors the home directory structure

source "$DOTFILES_DIR/scripts/vars.sh"
source "$DOTFILES_DIR/shell/utils.sh"

# Ensure required directories exist for stow packages
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude/plugins"

# Use system stow on Linux (Homebrew stow has Perl dependency issues)
# On macOS, use Homebrew stow
if [[ "$(uname)" == "Linux" ]] && [[ -x /usr/bin/stow ]]; then
  STOW_CMD="/usr/bin/stow"
else
  STOW_CMD="stow"
fi

# Remove conflicting files before stowing (backup handled separately)
# remove_conflicts removes regular (non-symlink) files in $HOME that correspond to files in the specified package so GNU Stow can create symlinks; files named .stow-local-ignore are ignored and removed files are not backed up.
# The single argument is the package name located under DOTFILES_DIR whose files are compared against $HOME.
remove_conflicts() {
  local package="$1"
  local package_dir="$DOTFILES_DIR/$package"

  # Find all files in the package and remove corresponding files in home
  # Matches both top-level dotfiles and files inside dotfile directories
  find "$package_dir" -type f ! -name ".stow-local-ignore" | while read -r file; do
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
    # Skip claude-code if user already has settings (preserve existing config)
    if [ "$package" = "claude-code" ] && [ -f "$HOME/.claude/settings.json" ] && [ ! -L "$HOME/.claude/settings.json" ]; then
      echo "   Skipping $package: existing ~/.claude/settings.json preserved"
      continue
    fi
    echo "   Stowing $package..."
    remove_conflicts "$package"
    $STOW_CMD -v -d "$DOTFILES_DIR" -t "$HOME" "$package" 2>&1 | grep -v "^BUG" || true
  else
    print_error "Package directory not found: $package"
  fi
done

print_success "Symlinks created via Stow"