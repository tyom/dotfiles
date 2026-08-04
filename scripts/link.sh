#!/bin/bash

# Create the dotfile symlinks
# The home/ directory mirrors the home directory structure

# vars.sh sets DOTFILES_DIR if it isn't already, so this works when run directly
# as well as when setup.sh sources it. Relative path: $DOTFILES_DIR may be unset.
source "$(dirname "${BASH_SOURCE[0]}")/vars.sh"
source "$DOTFILES_DIR/shell/utils.sh"

SRC_DIR="$DOTFILES_DIR/home"
REPO=$(cd "$DOTFILES_DIR" && pwd -P)

# setup.sh sets this when the agent instructions weren't selected. Unset means a
# direct run of this script, which links everything.
SKIP_AGENTS=${SKIP_AGENTS:-false}

if [ "$SKIP_AGENTS" = true ]; then
  print_skip 'Agent instructions not selected, leaving ~/.claude and ~/.codex alone'
else
  # The agent instruction files under home/ are generated, so build them before
  # linking or an install can ship a stale copy. Skipped above rather than built
  # and ignored, so opting out leaves nothing behind in the working tree.
  bash "$DOTFILES_DIR/scripts/build-agents.sh" || {
    # Sourced, so this is setup.sh's status. Linking a stale generated file is
    # worse than stopping: the agent would silently follow the old rules.
    print_error 'Could not build the agent instruction files'
    exit 1
  }
fi

link() {
  if mkdir -p "$(dirname "$2")" && ln -sfn "$1" "$2"; then
    print_info "linked ${2#"$HOME"/}"
  else
    # Say so, or the run ends on "Symlinks created" with a link missing.
    print_warning "Could not link $2"
  fi
}

while read -r file; do
  rel_path="${file#"$SRC_DIR"/}"
  target="$HOME/$rel_path"

  if [ "$SKIP_AGENTS" = true ]; then
    case "$rel_path" in .claude/CLAUDE.md | .codex/AGENTS.md) continue ;; esac
  fi

  if [ -L "$target" ]; then
    # Ours to refresh if it already points into this repo, or if it dangles
    # because the repo moved. A link the user made elsewhere still resolves.
    if [ ! -e "$target" ] || links_into "$REPO" "$target"; then
      link "$file" "$target"
    else
      print_warning "Links outside this repo, leaving it alone: $target"
    fi
    continue
  fi

  if [ ! -e "$target" ]; then
    link "$file" "$target"
    continue
  fi

  # Anything that isn't a regular file is a conflict the prompts below can't
  # speak to, so hand it back to the user.
  if [ ! -f "$target" ]; then
    print_warning "Not a regular file, leaving it alone: $target"
    continue
  fi

  # Nothing to lose in an empty file, so take it without asking. Anything with
  # bytes in it goes to the prompt below, readable or not, so a file we cannot
  # read is never deleted here.
  if [ ! -s "$target" ]; then
    if rm "$target" 2>/dev/null; then
      print_info "Removed empty $target"
      link "$file" "$target"
    else
      print_warning "Cannot remove, leaving it alone: $target"
    fi
    continue
  fi

  # -e /dev/tty is true even with no controlling terminal, so open it instead
  if ! : 2>/dev/null </dev/tty; then
    print_warning "Existing file, leaving it alone: $target"
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
    # -L too: a dangling .bak is still someone's backup, and -e misses it.
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      backup="$target.bak.$n"
      n=$((n + 1))
    done
    if ! mv "$target" "$backup"; then
      print_warning "Cannot back up, leaving it alone: $target"
      continue
    fi
    print_success "Moved to $backup"
    link "$file" "$target"
    ;;
  [qQ])
    # This script is sourced, so the status is setup.sh's status. Quitting
    # part-way is not a successful install, and exit 0 here would skip the
    # remaining steps while reporting success.
    print_error "Stopped at $rel_path. Links made before it are left in place."
    exit 1
    ;;
  *)
    print_skip "Skipped $rel_path"
    ;;
  esac
done < <(find "$SRC_DIR" -type f ! -name .DS_Store)

print_success "Symlinks created"
