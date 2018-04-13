#!/bin/bash

source shell/utils

print_step 'Installing vim-plug' && \
  curl -fLo "$HOME"/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

vim -E -s +PlugUpgrade +qa
vim -u "$HOME/.vimrc.bundles" +'PlugUpdate' +PlugClean! +qa
