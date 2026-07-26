#!/bin/bash

# Create symlinks using GNU Stow
# The stow/ directory mirrors the home directory structure

source "$DOTFILES_DIR/shell/utils.sh"

# The agent instruction files under stow/ are generated, so build them before
# linking or an install can ship a stale copy.
bash "$DOTFILES_DIR/scripts/build-agents.sh"

# Pre-create every directory that stow/ contains. Stow folds a whole directory
# into one symlink when the target doesn't exist yet, so without this, ~/.config
# would become a link into this repo and every tool's config would land in the
# working tree. One line per directory added under stow/.
mkdir -p "$HOME/bin" "$HOME/.config/ghostty" "$HOME/.claude" "$HOME/.codex"

# Use system stow on Linux (Homebrew stow has Perl dependency issues)
if [[ "$(uname)" == "Linux" ]] && [[ -x /usr/bin/stow ]]; then
  STOW_CMD="/usr/bin/stow"
else
  STOW_CMD="stow"
fi

# Resolve conflicting files before stowing. Stow aborts every symlink on a
# single conflict, so one stray file blocks the whole install. Agent tools leave
# an empty ~/.claude/CLAUDE.md or ~/.codex/AGENTS.md behind, which used to be
# enough to stop it.
STOW_DIR="$DOTFILES_DIR/stow"
STOW_IGNORE=()

# Exclude one file from this stow run. --ignore takes a Perl regex matched
# against the basename, so the dots have to be escaped.
skip_file() {
  STOW_IGNORE+=(--ignore="$(basename "$1" | sed 's/\./\\./g')")
}

# setup.sh sets this when the agent instructions weren't selected. Unset means a
# direct run of this script, which links everything as before.
if [ "${STOW_SKIP_AGENTS:-false}" = true ]; then
  skip_file CLAUDE.md
  skip_file AGENTS.md
  print_skip 'Agent instructions not selected, leaving ~/.claude and ~/.codex alone'
fi

while read -r file; do
  rel_path="${file#"$STOW_DIR"/}"
  target="$HOME/$rel_path"

  # A symlink is stow's own work. Anything else that isn't a regular file is a
  # conflict the prompts below can't speak to, so hand it back to the user
  # rather than letting it abort the package.
  [ -L "$target" ] && continue
  if [ -e "$target" ] && [ ! -f "$target" ]; then
    print_warning "Not a regular file, leaving it alone: $target"
    skip_file "$target"
    continue
  fi
  [ -f "$target" ] || continue

  # Nothing to lose in an empty file, so take it without asking. Status 1 is
  # "no match", anything higher is a read error — never delete on those.
  grep -q '[^[:space:]]' "$target" 2>/dev/null
  case $? in
  1)
    if rm "$target" 2>/dev/null; then
      print_info "Removed empty $target"
    else
      print_warning "Cannot remove, leaving it alone: $target"
      skip_file "$target"
    fi
    continue
    ;;
  0) ;;
  *)
    print_warning "Cannot read, leaving it alone: $target"
    skip_file "$target"
    continue
    ;;
  esac

  # -e /dev/tty is true even with no controlling terminal, so open it instead
  if ! : 2>/dev/null </dev/tty; then
    print_warning "Existing file, leaving it alone: $target"
    skip_file "$target"
    continue
  fi

  print_warning "$target exists and is not empty:"
  head -15 "$target" | sed 's/^/   │ /'
  total=$(wc -l <"$target")
  [ "$total" -gt 15 ] && print_info "… $((total - 15)) more line(s)"
  print_question "[o]verride (keeps a .bak), [s]kip, [q]uit? "
  read -n 1 -r key </dev/tty || key=s
  echo

  case "$key" in
  [oO])
    backup="$target.bak"
    n=1
    while [ -e "$backup" ]; do
      backup="$target.bak.$n"
      n=$((n + 1))
    done
    mv "$target" "$backup"
    print_success "Moved to $backup"
    ;;
  [qQ])
    # This script is sourced, so the status is setup.sh's status. Quitting
    # part-way is not a successful install, and exit 0 here would skip the
    # remaining steps while reporting success.
    print_error "Stopped at $rel_path. Nothing was changed."
    exit 1
    ;;
  *)
    skip_file "$target"
    print_skip "Skipped $rel_path"
    ;;
  esac
done < <(find "$STOW_DIR" -type f ! -name .DS_Store)

# Stow the entire stow/ directory
STOW_OUTPUT=$($STOW_CMD -v --ignore='\.DS_Store' "${STOW_IGNORE[@]}" -d "$DOTFILES_DIR" -t "$HOME" stow 2>&1)
STOW_EXIT=$?
print_stow_output <<<"$STOW_OUTPUT"
if [ $STOW_EXIT -ne 0 ]; then
  print_error "Stow failed. Check conflicts above and resolve manually."
  exit 1
fi

print_success "Symlinks created via Stow"
