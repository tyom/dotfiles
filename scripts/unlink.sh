#!/bin/bash

# Remove the symlinks that link.sh created
# Only links that still point into this repo are touched

# Relative to this file, not $DOTFILES_DIR: vars.sh is what sets that, and
# `make uninstall` runs this script with nothing exported.
source "$(dirname "${BASH_SOURCE[0]}")/vars.sh"
source "$DOTFILES_DIR/shell/utils.sh"

print_step "Removing dotfile symlinks..."

HOME_DIR="$DOTFILES_DIR/home"
REPO=$(cd "$DOTFILES_DIR" && pwd -P)

while read -r file; do
  rel_path="${file#"$HOME_DIR"/}"
  target="$HOME/$rel_path"

  [ -L "$target" ] || continue
  # A live link elsewhere is the user's own, so leave it. A dangling one is ours
  # from an install made before the repo moved.
  [ -e "$target" ] && ! links_into "$REPO" "$target" && continue

  if rm "$target"; then
    print_info "unlinked $rel_path"
  else
    print_warning "Could not unlink $target"
  fi
done < <(find "$HOME_DIR" -type f ! -name .DS_Store)

# rmdir only removes empty directories, so this clears out what the links left
# behind and leaves anything the user still keeps there. Deepest first.
while read -r dir; do
  rmdir "$dir" 2>/dev/null
done < <(find "$HOME_DIR" -mindepth 1 -type d | sed "s|^$HOME_DIR|$HOME|" | sort -r)

print_success "Symlinks removed"
