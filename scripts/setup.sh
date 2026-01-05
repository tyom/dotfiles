#!/bin/bash

source scripts/vars.sh
source shell/utils.sh

echo -e "Installing dotfiles for $(which_os)…"

continue_or_exit \
  'This will install dotfiles for your system and update your .zshrc file.' 'y'

continue_or_skip \
  'Install Homebrew and useful packages? This may take a while.' 'y' &&
  source "$DOTFILES_DIR/scripts/install/brew.sh" ||
  print_info 'Skipping Homebrew'

if [ "$(which_os)" == "macos" ]; then
  continue_or_skip \
    'Install brew cask (macOS apps via Homebrew)?' 'y' &&
    source "$DOTFILES_DIR/scripts/install/brew-cask.sh" ||
    print_info 'Skipping Brew Cask'
fi

# Install Bun via Homebrew (optional, for faster JS tooling)
if command -v brew &>/dev/null; then
  continue_or_skip 'Install Bun (faster JS tooling)?' 'y' && {
    if ! command -v bun &>/dev/null; then
      print_step 'Installing Bun'
      brew install oven-sh/bun/bun
    else
      print_info 'Bun already installed'
    fi
  } || print_info 'Skipping Bun'
fi

# Install Volta (Node.js version manager)
if ! command -v volta &>/dev/null; then
  print_step 'Installing Volta'
  curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
else
  print_info 'Volta already installed'
fi

# Install default Node.js via Volta
if command -v volta &>/dev/null && ! volta which node &>/dev/null; then
  print_step 'Installing Node.js via Volta'
  volta install node
else
  print_info 'Node.js already installed via Volta'
fi

print_step 'Setting up zsh' &&
  source "$DOTFILES_DIR/scripts/zsh.sh"

print_step 'Symlinking dotfiles' &&
  source "$DOTFILES_DIR/scripts/stow.sh"

print_step 'Setting up git' &&
  source "$DOTFILES_DIR/scripts/git.sh"

print_step 'Installing Vim plugins' &&
  source "$DOTFILES_DIR/scripts/install/vim.sh"

# Claude Code plugin setup (optional)
PLUGIN_DIR="$DOTFILES_DIR/claude-plugin"
if [ -f "$PLUGIN_DIR/package.json" ]; then
  continue_or_skip \
    'Install Claude Code plugin?' 'y' && {
    print_step 'Installing Claude Code plugin dependencies'
    if command -v bun &>/dev/null; then
      if (cd "$PLUGIN_DIR" && (bun install --frozen-lockfile || bun install)); then
        print_success 'Dependencies installed via bun'
      else
        print_error 'Failed to install dependencies via bun'
      fi
    elif command -v npm &>/dev/null; then
      if (cd "$PLUGIN_DIR" && npm install); then
        print_success 'Dependencies installed via npm'
      else
        print_error 'Failed to install dependencies via npm'
      fi
    else
      print_info 'Skipping: neither bun nor npm available'
    fi

    # Register plugin if claude is available
    if command -v claude &>/dev/null; then
      print_step 'Registering Claude Code dotfiles plugin'
      if claude plugin marketplace add "$PLUGIN_DIR" &>/dev/null; then
        print_success 'Plugin marketplace entry added'
      else
        print_info 'Plugin marketplace entry may already exist'
      fi
      if claude plugin install dotfiles@tyom --scope user &>/dev/null; then
        print_success 'Plugin installed successfully'
      else
        print_info 'Plugin may already be installed'
      fi
    fi
  } || print_info 'Skipping Claude Code plugin'
fi

print_step 'Validating installation'
"$DOTFILES_DIR/scripts/validate.sh"

echo ""
print_success 'dotfiles are installed! Start a new shell session.'
