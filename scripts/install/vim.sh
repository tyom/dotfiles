#!/bin/bash

source shell/utils.sh

# Install vim-plug plugin manager
print_step 'Installing vim-plug'
curl -fLo "$HOME"/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Check if .vimrc.bundles exists (should be symlinked by now)
if [ ! -f "$HOME/.vimrc.bundles" ]; then
  print_error "~/.vimrc.bundles not found. Ensure symlinks were created."
  exit 1
fi

# Install vim plugins in headless mode (works in Docker/CI)
# --sync flag ensures PlugInstall completes before exiting
print_step 'Installing Vim plugins'
vim -u "$HOME/.vimrc.bundles" -c 'PlugInstall --sync' -c 'qa!' 2>/dev/null

print_success 'Vim plugins installed'
