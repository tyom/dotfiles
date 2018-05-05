#!/bin/bash

for file in ${PAYLOAD_FILES[@]}; do
  ln -sf "$DOTFILES_DIR/payload/$file" "$HOME/.$file"
  echo "   .$file"
done

ln -fs "$DOTFILES_DIR/shell/tyom.zsh-theme" "$HOME/.oh-my-zsh/themes"
