#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/vars.sh"
source "$DOTFILES_DIR/scripts/versions.sh"
source "$DOTFILES_DIR/shell/utils.sh"

install_zsh() {
  platform=$(which_os)

  SUDO_CMD=""
  if [ "$(id -u)" != "0" ]; then
    SUDO_CMD="sudo"
  fi

  if [[ $platform == 'redhat' ]]; then
    ${SUDO_CMD} yum install zsh -y
  elif [[ $platform == 'debian' ]]; then
    ${SUDO_CMD} apt-get install zsh -y
  elif [[ $platform == 'macos' ]]; then
    brew install zsh
  fi
}

if exists zsh; then
  print_info "zsh is already installed. Skipping."
else
  install_zsh
  # Nothing below needs zsh to be the *current* shell, so carry on; only stop
  # if the install actually failed.
  if ! exists zsh; then
    print_error "zsh install failed; cannot continue"
    exit 1
  fi
  print_success "zsh installed"
fi

# Install Oh My Zsh if it isn't already present
if [[ ! -d $HOME/.oh-my-zsh/ ]]; then
  OMZ_TMP=$(mktemp -d "$HOME/.oh-my-zsh.install.XXXXXX")
  if git -C "$OMZ_TMP" init -q &&
    git -C "$OMZ_TMP" remote add origin "$OH_MY_ZSH_REMOTE" &&
    git -C "$OMZ_TMP" fetch -q --depth 1 origin "$OH_MY_ZSH_COMMIT" &&
    git -C "$OMZ_TMP" checkout -q -B master FETCH_HEAD &&
    [ "$(git -C "$OMZ_TMP" rev-parse HEAD)" = "$OH_MY_ZSH_COMMIT" ]; then
    git -C "$OMZ_TMP" config oh-my-zsh.remote origin
    git -C "$OMZ_TMP" config oh-my-zsh.branch master
    mv "$OMZ_TMP" "$HOME/.oh-my-zsh"
    print_success 'Oh My Zsh installed at the reviewed commit'
  else
    rm -rf "$OMZ_TMP"
    print_error 'Oh My Zsh installation failed'
    exit 1
  fi
else
  print_info 'oh-my-zsh is already installed. Skipping.'
fi

# Symlink custom theme
mkdir -p "$HOME/.oh-my-zsh/custom/themes"
THEME_TARGET="$HOME/.oh-my-zsh/custom/themes/tyom.zsh-theme"
if [ -e "$THEME_TARGET" ] && [ ! -L "$THEME_TARGET" ]; then
  print_warning "Existing theme file found: $THEME_TARGET (skipping symlink)"
else
  ln -sf "$DOTFILES_DIR/zsh/tyom.zsh-theme" "$THEME_TARGET"
  print_success "Custom theme symlinked"
fi

# Set up .zshrc to source our dotfiles config
DOTFILES_SOURCE_LINE="export DOTFILES_DIR=\"$DOTFILES_DIR\" && source \"\$DOTFILES_DIR/zsh/dotfiles.zsh\""

if grep -qF "source \"\$DOTFILES_DIR/zsh/dotfiles.zsh\"" "$HOME/.zshrc" 2>/dev/null; then
  print_info "Dotfiles already sourced in .zshrc"
else
  # Always append to existing .zshrc or create if it doesn't exist
  if [[ -f "$HOME/.zshrc" ]]; then
    # Append to existing .zshrc (never overwrite)
    echo "" >>"$HOME/.zshrc"
    echo "# Dotfiles" >>"$HOME/.zshrc"
    echo "$DOTFILES_SOURCE_LINE" >>"$HOME/.zshrc"
    print_success "Added dotfiles source line to .zshrc"
  else
    # Create new .zshrc if it doesn't exist
    echo "$DOTFILES_SOURCE_LINE" >"$HOME/.zshrc"
    print_success "Created .zshrc"
  fi

  # If user needs manual action, provide instructions
  if [[ ! -w "$HOME/.zshrc" ]]; then
    print_error "Cannot write to .zshrc. Please manually add the following line to your .zshrc:"
    print_info "$DOTFILES_SOURCE_LINE"
    exit 1
  fi
fi

print_success "Dotfiles configured (DOTFILES_DIR=$DOTFILES_DIR)"
