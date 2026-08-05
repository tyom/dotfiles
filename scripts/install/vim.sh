#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"
source "$DOTFILES_DIR/shell/utils.sh"

# Install vim-plug plugin manager. -sS keeps curl quiet but still reports a
# failure, which the bare -f used to swallow into a silent broken install.
# Download to a temp file first: curl leaves a truncated plug.vim behind on a
# failed transfer, and the check above would then treat it as installed.
if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
  print_info 'vim-plug already installed, skipping'
elif curl -fsSLo "$HOME"/.vim/autoload/plug.vim.part --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
  mv "$HOME/.vim/autoload/plug.vim.part" "$HOME/.vim/autoload/plug.vim"
  print_info 'vim-plug installed'
else
  rm -f "$HOME/.vim/autoload/plug.vim.part"
  print_error 'Failed to download vim-plug'
  exit 1
fi

# Check if .vimrc.bundles exists (should be symlinked by now)
if [ ! -f "$HOME/.vimrc.bundles" ]; then
  print_error "~/.vimrc.bundles not found. Ensure symlinks were created."
  exit 1
fi

# Install vim plugins in headless mode (works in Docker/CI). -es is silent ex
# mode: the plain -u form opens the full UI, which flashes over the installer on
# a terminal and dumps raw escape codes into a redirected log.
# --sync ensures PlugInstall completes before vim exits.
# PlugInstall exits 0 even when a clone fails and prints nothing in silent mode,
# so check g:plugs for a plugin that has no directory and cquit on one.
PLUG_CHECK='if !empty(filter(values(g:plugs), "!isdirectory(v:val.dir)")) | cquit | endif'
if ! vim -es -u "$HOME/.vimrc.bundles" -i NONE \
  -c 'PlugInstall --sync' -c "$PLUG_CHECK" -c 'qa!' </dev/null >/dev/null 2>&1; then
  print_error 'Vim plugin install failed'
  exit 1
fi

print_success 'Vim plugins installed'
