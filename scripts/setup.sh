#!/bin/bash

source scripts/vars.sh
source scripts/versions.sh
source shell/utils.sh

# The menu needs a tty, so -y and --select are how a script or CI picks what to
# install. Both also work as environment variables (YES_OVERRIDE, SELECT_OVERRIDE).
VERBOSE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
  -v | --verbose) VERBOSE=true ;;
  -y | --yes) YES_OVERRIDE=true ;;
  -s | --select | --select=*)
    if [[ "$1" == --select=* ]]; then
      SELECT_OVERRIDE="${1#*=}"
    else
      SELECT_OVERRIDE="${2-}"
      shift
    fi
    # multi_select treats an empty override as "not given" and quietly installs
    # the defaults, so a mistyped --select must fail here instead.
    [[ -n "$SELECT_OVERRIDE" ]] || {
      print_error '--select needs a comma-separated list of options'
      exit 1
    }
    ;;
  -h | --help)
    echo "Usage: setup.sh [-y] [--select name,name] [--verbose]"
    exit 0
    ;;
  *)
    print_error "Unknown option: $1"
    exit 1
    ;;
  esac
  shift
done

SUMMARY=()

echo -e "Installing dotfiles for $(which_os)…"
echo ""

options=(
  'dotfiles|Symlink dotfiles, set up zsh, git and vim|on'
  'agents|Global agent instructions (Claude, Codex)|off'
  'node|Volta + default Node.js|on'
)
if [[ "${MINIMAL_SETUP:-}" != "true" ]]; then
  options+=('brew|Homebrew + CLI packages|off')
  [ "$(which_os)" == "macos" ] &&
    options+=('casks|macOS apps and Quick Look plugins|off')
  options+=('bun|Bun (faster JS tooling)|off')
fi
# Unconditional: the plugin ships with this repo, so a file test here can only
# ever be true — and when the file it named was deleted, the option vanished from
# the checklist with no message rather than failing.
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
    BUN_INSTALLER=$(mktemp)
    if download_verified "$BUN_INSTALL_URL" "$BUN_INSTALL_SHA256" "$BUN_INSTALLER" &&
      bash "$BUN_INSTALLER" "bun-v$BUN_VERSION"; then
      rm -f "$BUN_INSTALLER"
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
      if command -v bun &>/dev/null; then
        SUMMARY+=('Bun: installed')
      else
        print_error 'Bun installer completed but bun is not available'
        exit 1
      fi
    else
      rm -f "$BUN_INSTALLER"
      print_error 'Bun installation failed'
      exit 1
    fi
  else
    print_info 'Bun already installed'
    SUMMARY+=('Bun: already installed')
  fi
fi

if is_checked node; then
  if ! command -v volta &>/dev/null; then
    print_step 'Installing Volta'
    VOLTA_INSTALLER=$(mktemp)
    if download_verified "$VOLTA_INSTALL_URL" "$VOLTA_INSTALL_SHA256" "$VOLTA_INSTALLER" &&
      bash "$VOLTA_INSTALLER" --version "$VOLTA_VERSION" --skip-setup; then
      rm -f "$VOLTA_INSTALLER"
      export VOLTA_HOME="$HOME/.volta"
      export PATH="$VOLTA_HOME/bin:$PATH"
      if command -v volta &>/dev/null; then
        SUMMARY+=('Volta: installed')
      else
        print_error 'Volta installer completed but volta is not available'
        exit 1
      fi
    else
      rm -f "$VOLTA_INSTALLER"
      print_error 'Volta installation failed'
      exit 1
    fi
  else
    print_info 'Volta already installed'
    SUMMARY+=('Volta: already installed')
  fi

  if ! volta which node &>/dev/null; then
    print_step 'Installing Node.js via Volta'
    if volta install node && volta which node &>/dev/null; then
      SUMMARY+=('Node.js: installed via Volta')
    else
      print_error 'Node.js installation via Volta failed'
      exit 1
    fi
  else
    print_info 'Node.js already installed via Volta'
    SUMMARY+=('Node.js: already installed')
  fi
fi

# The agent files are linked as part of the symlinking step, so on their own
# there is nothing to run. Say so rather than reporting a silent success.
if is_checked agents && ! is_checked dotfiles; then
  print_warning 'Agent instructions are linked by the dotfiles option, which is not selected'
  SUMMARY+=('agents: skipped, needs the dotfiles option')
fi

# These four are run, not sourced. None of them exports anything the steps after
# it read, and sourcing meant a bare `exit` inside one ended the whole installer
# reporting success — a trap that needed a comment in each script and a grep step
# in CI to police. As subprocesses their status is just a status.
if is_checked dotfiles; then
  print_step 'Setting up zsh'
  bash "$DOTFILES_DIR/scripts/zsh.sh" || exit 1

  # These land in ~/.claude and ~/.codex and steer every agent session on the
  # machine, so they are opt-in rather than part of the dotfiles bundle. Passed
  # explicitly so an inherited SKIP_AGENTS can't survive the option being ticked.
  if is_checked agents; then SKIP_AGENTS=false; else SKIP_AGENTS=true; fi

  print_step 'Symlinking dotfiles'
  SKIP_AGENTS=$SKIP_AGENTS bash "$DOTFILES_DIR/scripts/link.sh" || exit 1

  print_step 'Setting up git'
  bash "$DOTFILES_DIR/scripts/git.sh" || exit 1

  print_step 'Installing Vim plugins'
  bash "$DOTFILES_DIR/scripts/install/vim.sh" || exit 1
fi

if is_checked claude-plugin; then
  PLUGIN_DIR="$DOTFILES_DIR/claude-plugin"

  # The hook is plain JS on node: builtins, so there is nothing to install. It
  # needs node on PATH at run time, which the 'node' item above provides.
  if ! command -v node &>/dev/null; then
    print_warning 'node not found, the plugin hook will not run until it is'
  fi

  # Register plugin if claude is available
  if ! command -v claude &>/dev/null; then
    print_warning 'claude not found, the plugin cannot be registered'
    SUMMARY+=('Claude Code plugin: skipped, claude not found')
  else
    print_step 'Registering Claude Code dotfiles plugin'
    if claude plugin marketplace add "$PLUGIN_DIR" &>/dev/null; then
      print_success 'Plugin marketplace entry added'
    else
      print_info 'Plugin marketplace entry may already exist'
    fi
    # A failed install is usually one that was already there, so ask the list
    # rather than reporting either outcome on the exit status alone.
    if claude plugin install dotfiles@tyom --scope user &>/dev/null ||
      claude plugin list 2>/dev/null | grep -q 'dotfiles@tyom'; then
      print_success 'Plugin installed'
      SUMMARY+=('Claude Code plugin: installed')
    else
      print_error 'Plugin installation failed'
      SUMMARY+=('Claude Code plugin: install failed')
    fi
  fi
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
