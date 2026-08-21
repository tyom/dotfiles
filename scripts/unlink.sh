#!/bin/bash

# Remove the symlinks that link.sh created
# Only links that still point into this repo are touched

# Relative to this file, not $DOTFILES_DIR: vars.sh is what sets that, and
# `make uninstall` runs this script with nothing exported.
source "$(dirname "${BASH_SOURCE[0]}")/vars.sh"
source "$DOTFILES_DIR/shell/utils.sh"

print_step "Removing dotfile symlinks..."

SRC_DIR="$DOTFILES_DIR/home"
REPO=$(cd "$DOTFILES_DIR" && pwd -P)

while read -r file; do
  rel_path="${file#"$SRC_DIR"/}"
  target="$HOME/$rel_path"

  [ -L "$target" ] || continue
  # Remove only links whose live or unresolved target proves they are ours.
  links_into "$REPO" "$target" || continue

  if rm "$target"; then
    print_info "unlinked $rel_path"
  else
    print_warning "Could not unlink $target"
  fi
done < <(find "$SRC_DIR" -type f ! -name .DS_Store)

# link.sh points ~/.claude/skills and ~/.codex/skills at each shared skill
# outside the loop above, so those directory links need removing here or
# uninstall leaves them dangling.
for skill in "$SRC_DIR"/.agents/skills/*/; do
  [ -d "$skill" ] || continue
  for skills_dir in .claude/skills .codex/skills; do
    rel_path="$skills_dir/$(basename "$skill")"
    target="$HOME/$rel_path"

    [ -L "$target" ] || continue
    links_into "$REPO" "$target" || continue

    if rm "$target"; then
      print_info "unlinked $rel_path"
    else
      print_warning "Could not unlink $target"
    fi
  done
done

# rmdir only removes empty directories, so this clears out what the links left
# behind and leaves anything the user still keeps there. Deepest first.
while read -r dir; do
  rmdir "$HOME/${dir#"$SRC_DIR"/}" 2>/dev/null
done < <(find "$SRC_DIR" -mindepth 1 -type d | sort -r)

print_success "Symlinks removed"
