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

# Install Bun (required for Claude Code plugin and JS tooling)
if ! command -v bun &> /dev/null; then
  print_step 'Installing Bun'
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
else
  print_info 'Bun already installed'
fi

# Install Volta (Node.js version manager)
if ! command -v volta &> /dev/null; then
  print_step 'Installing Volta'
  curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
else
  print_info 'Volta already installed'
fi

# Install default Node.js via Volta
if command -v volta &> /dev/null && ! volta list node 2>/dev/null | grep -q 'node@'; then
  print_step 'Installing Node.js via Volta'
  volta install node
else
  print_info 'Node.js already installed via Volta'
fi

print_step 'Setting up zsh' &&
  source "$DOTFILES_DIR/scripts/zsh.sh"

print_step 'Symlinking dotfiles' &&
  source "$DOTFILES_DIR/scripts/stow.sh"

print_step 'Installing Vim plugins' &&
  source "$DOTFILES_DIR/scripts/install/vim.sh"

# Install Claude Code plugin dependencies (always, so they're ready when Claude is installed)
PLUGIN_DIR="$DOTFILES_DIR/claude-code/.claude/plugin"
if [ -f "$PLUGIN_DIR/package.json" ]; then
  print_step 'Installing Claude Code plugin dependencies'
  (cd "$PLUGIN_DIR" && bun install --frozen-lockfile 2>/dev/null || bun install)
fi

# Register Claude Code plugin if claude is available
if command -v claude &> /dev/null; then
  print_step 'Registering Claude Code dotfiles plugin'
  claude plugin marketplace add "$HOME/.claude/plugin" 2>/dev/null || true
  claude plugin install dotfiles@dotfiles --scope user 2>/dev/null || true
fi

print_step 'Validating installation'
"$DOTFILES_DIR/scripts/validate.sh"

echo ""
print_success 'dotfiles are installed! Start a new shell session.'
