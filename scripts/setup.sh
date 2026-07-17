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
echo ""

options=(
  'dotfiles|Symlink dotfiles, set up zsh, git and vim|on'
  'node|Volta + default Node.js|on'
)
if [[ "${MINIMAL_SETUP:-}" != "true" ]]; then
  options+=('brew|Homebrew + CLI packages|off')
  [ "$(which_os)" == "macos" ] &&
    options+=('casks|macOS apps and Quick Look plugins|off')
  options+=('bun|Bun (faster JS tooling)|off')
fi
[ -f "$DOTFILES_DIR/claude-plugin/package.json" ] &&
  options+=('claude-plugin|Claude Code dotfiles plugin|off')

multi_select 'Select what to install (nothing selected = exit):' "${options[@]}"

if [ ${#CHECKED[@]} -eq 0 ]; then
  print_info 'Nothing selected. Exiting.'
  exit 0
fi

for entry in "${options[@]}"; do
  is_checked "${entry%%|*}" || SUMMARY+=("${entry%%|*}: skipped")
done

if is_checked brew; then
  source "$DOTFILES_DIR/scripts/install/brew.sh"
fi

if is_checked casks; then
  source "$DOTFILES_DIR/scripts/install/brew-cask.sh"
fi

if is_checked bun; then
  if ! command -v bun &>/dev/null; then
    print_step 'Installing Bun'
    if curl -fsSL https://bun.com/install | bash; then
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
      SUMMARY+=('Bun: installed')
    else
      SUMMARY+=('Bun: install failed')
    fi
  else
    print_info 'Bun already installed'
    SUMMARY+=('Bun: already installed')
  fi
fi

if is_checked node; then
  if ! command -v volta &>/dev/null; then
    print_step 'Installing Volta'
    if curl -fsSL https://get.volta.sh | bash -s -- --skip-setup; then
      export VOLTA_HOME="$HOME/.volta"
      export PATH="$VOLTA_HOME/bin:$PATH"
      SUMMARY+=('Volta: installed')
    else
      SUMMARY+=('Volta: install failed')
    fi
  else
    print_info 'Volta already installed'
    SUMMARY+=('Volta: already installed')
  fi

  if command -v volta &>/dev/null && ! volta which node &>/dev/null; then
    print_step 'Installing Node.js via Volta'
    volta install node
    SUMMARY+=('Node.js: installed via Volta')
  else
    print_info 'Node.js already installed via Volta'
    SUMMARY+=('Node.js: already installed')
  fi
fi

if is_checked dotfiles; then
  print_step 'Setting up zsh' &&
    source "$DOTFILES_DIR/scripts/zsh.sh"

  print_step 'Symlinking dotfiles' &&
    source "$DOTFILES_DIR/scripts/stow.sh"

  print_step 'Setting up git' &&
    source "$DOTFILES_DIR/scripts/git.sh"

  print_step 'Installing Vim plugins' &&
    source "$DOTFILES_DIR/scripts/install/vim.sh"
fi

if is_checked claude-plugin; then
  PLUGIN_DIR="$DOTFILES_DIR/claude-plugin"
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
fi

if is_checked dotfiles; then
  print_step 'Validating installation'
  if $VERBOSE; then
    "$DOTFILES_DIR/scripts/validate.sh" || exit 1
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
fi

echo ""
print_step 'Summary'
for line in "${SUMMARY[@]}"; do
  print_info "$line"
done

echo ""
print_success 'dotfiles are installed! Start a new shell session.'
