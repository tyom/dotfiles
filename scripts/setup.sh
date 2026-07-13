#!/bin/bash

source scripts/vars.sh
source shell/utils.sh

# --verbose / -v: show full validation output instead of a one-line summary
VERBOSE=false
for arg in "$@"; do
  [[ "$arg" == "--verbose" || "$arg" == "-v" ]] && VERBOSE=true
done

SUMMARY=()

echo -e "Installing dotfiles for $(which_os)…"

continue_or_exit \
  'This will install dotfiles for your system and update your .zshrc file.' 'y'

if [[ "${MINIMAL_SETUP:-}" == "true" ]]; then
  print_info 'Skipping Homebrew (minimal setup)'
  SUMMARY+=('Homebrew packages: skipped (minimal setup)')
else
  if continue_or_skip 'Install Homebrew and useful packages? This may take a while.' 'y'; then
    source "$DOTFILES_DIR/scripts/install/brew.sh"
    SUMMARY+=("Homebrew packages: installed (${#packages[@]})")
  else
    print_info 'Skipping Homebrew'
    SUMMARY+=('Homebrew packages: skipped')
  fi
fi

if [ "$(which_os)" == "macos" ]; then
  if continue_or_skip 'Install brew cask (macOS apps via Homebrew)?' 'y'; then
    source "$DOTFILES_DIR/scripts/install/brew-cask.sh"
    SUMMARY+=("Brew Cask apps: installed (${#casks[@]})")
  else
    print_info 'Skipping Brew Cask'
    SUMMARY+=('Brew Cask apps: skipped')
  fi
fi

# Install Bun (optional, for faster JS tooling)
if [[ "${MINIMAL_SETUP:-}" == "true" ]]; then
  print_info 'Skipping Bun (minimal setup)'
  SUMMARY+=('Bun: skipped (minimal setup)')
else
  if continue_or_skip 'Install Bun (faster JS tooling)?' 'y'; then
    if ! command -v bun &>/dev/null; then
      print_step 'Installing Bun'
      curl -fsSL https://bun.com/install | bash
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
      SUMMARY+=('Bun: installed')
    else
      print_info 'Bun already installed'
      SUMMARY+=('Bun: already installed')
    fi
  else
    print_info 'Skipping Bun'
    SUMMARY+=('Bun: skipped')
  fi
fi

# Install Volta (Node.js version manager)
if ! command -v volta &>/dev/null; then
  print_step 'Installing Volta'
  curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
  SUMMARY+=('Volta: installed')
else
  print_info 'Volta already installed'
  SUMMARY+=('Volta: already installed')
fi

# Install default Node.js via Volta
if command -v volta &>/dev/null && ! volta which node &>/dev/null; then
  print_step 'Installing Node.js via Volta'
  volta install node
  SUMMARY+=('Node.js: installed via Volta')
else
  print_info 'Node.js already installed via Volta'
  SUMMARY+=('Node.js: already installed')
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
  if continue_or_skip 'Install Claude Code plugin?' 'y'; then
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
    SUMMARY+=('Claude Code plugin: installed')
  else
    print_info 'Skipping Claude Code plugin'
    SUMMARY+=('Claude Code plugin: skipped')
  fi
fi

print_step 'Validating installation'
if $VERBOSE; then
  "$DOTFILES_DIR/scripts/validate.sh"
else
  # Quiet by default: one line with counts, full output on failure or --verbose
  if VALIDATE_OUT=$("$DOTFILES_DIR/scripts/validate.sh" 2>&1); then
    PASSED=$(echo "$VALIDATE_OUT" | grep -c ' ✔ ')
    WARNINGS=$(echo "$VALIDATE_OUT" | grep ' ⚠ ' || true)
    if [ -n "$WARNINGS" ]; then
      echo "$WARNINGS"
      print_success "Validation passed: $PASSED checks, $(echo "$WARNINGS" | wc -l | tr -d ' ') warning(s)"
    else
      print_success "Validation passed: $PASSED checks"
    fi
  else
    echo "$VALIDATE_OUT"
    exit 1
  fi
fi

echo ""
print_step 'Summary'
for line in "${SUMMARY[@]}"; do
  print_info "$line"
done

echo ""
print_success 'dotfiles are installed! Start a new shell session.'
