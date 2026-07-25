#!/bin/bash

source shell/utils.sh

# Install vim-plug plugin manager. -sS keeps curl quiet but still reports a
# failure, which the bare -f used to swallow into a silent broken install.
if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
  print_info 'vim-plug already installed, skipping'
elif curl -fsSLo "$HOME"/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
  print_info 'vim-plug installed'
else
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
if ! vim -es -u "$HOME/.vimrc.bundles" -i NONE \
  -c 'PlugInstall --sync' -c 'qa!' </dev/null >/dev/null 2>&1; then
  print_error 'Vim plugin install failed'
  exit 1
fi

print_success 'Vim plugins installed'
