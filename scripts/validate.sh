#!/bin/bash

# Validation script for dotfiles installation
# Checks that all symlinks and configurations are properly set up

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/shell/utils.sh"

# Symlink ownership is judged against the resolved path, the same way link.sh
# judges it. DOTFILES_DIR stays logical: the git include check below matches the
# path git.sh wrote, which is the unresolved one.
REPO=$(cd "$DOTFILES_DIR" && pwd -P)

ERRORS=0

print_step "Validating dotfiles installation..."

# Check the target is a live symlink pointing into this repo.
# The old test was `-L || -f`, which a regular file satisfies — so a stray copy,
# or a link left dangling after the repo moved, reported as installed.
check_symlink() {
  local target="$1"
  local desc="$2"

  if [ ! -L "$target" ]; then
    if [ -e "$target" ]; then
      print_error "$desc is a regular file, not a link into the repo: $target"
    else
      print_error "$desc missing: $target"
    fi
    ERRORS=$((ERRORS + 1))
    return
  fi

  if [ ! -e "$target" ]; then
    print_error "$desc is a dangling link: $target -> $(readlink "$target")"
    ERRORS=$((ERRORS + 1))
    return
  fi

  if links_into "$REPO" "$target"; then
    print_success "$desc links into the repo"
  else
    print_error "$desc points outside the repo: $target -> $(readlink "$target")"
    ERRORS=$((ERRORS + 1))
  fi
}

echo ""
print_info "Checking symlinks..."

# Git files are handled separately (not symlinked)
if [ -f "$HOME/.gitconfig" ]; then
  print_success ".gitconfig exists"
else
  print_error ".gitconfig missing"
  ERRORS=$((ERRORS + 1))
fi
if [ -f "$HOME/.gitignore" ]; then
  print_success ".gitignore exists"
else
  print_error ".gitignore missing"
  ERRORS=$((ERRORS + 1))
fi
check_symlink "$HOME/.vimrc" ".vimrc"
check_symlink "$HOME/.vimrc.bundles" ".vimrc.bundles"
check_symlink "$HOME/.config/ghostty/config.ghostty" "ghostty config"
check_symlink "$HOME/.oh-my-zsh/custom/themes/tyom.zsh-theme" "zsh theme"

# The agent instructions are opt-in, so a missing CLAUDE.md is not a failure and
# one the user wrote themselves is not ours to judge — hence the ownership test.
# For ours, the import is the thing worth checking: Claude Code reads the shared
# rules through it, and if it stops resolving there is no error anywhere, just a
# session running on an instruction file with nothing in it.
echo ""
print_info "Checking agent instructions..."

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -L "$CLAUDE_MD" ] && [ -e "$CLAUDE_MD" ] && links_into "$REPO" "$CLAUDE_MD"; then
  IMPORT=$(grep -m1 '^@' "$CLAUDE_MD" || true)
  if [ -z "$IMPORT" ]; then
    print_error "CLAUDE.md has no @import line, so it carries no shared rules"
    ERRORS=$((ERRORS + 1))
  elif [ -e "$HOME/.claude/${IMPORT#@}" ]; then
    print_success "CLAUDE.md imports ${IMPORT#@}"
  else
    print_error "CLAUDE.md imports ${IMPORT#@}, which does not resolve"
    ERRORS=$((ERRORS + 1))
  fi
else
  print_skip "agent instructions not installed, skipping"
fi

# Ghostty can check its own config, which catches typos in option names that it
# would otherwise ignore in silence. The CLI lives inside the app bundle on macOS.
echo ""
print_info "Checking ghostty config..."

GHOSTTY_BIN=$(command -v ghostty || echo "/Applications/Ghostty.app/Contents/MacOS/ghostty")
if [ -x "$GHOSTTY_BIN" ]; then
  if GHOSTTY_OUT=$("$GHOSTTY_BIN" +validate-config --config-file="$HOME/.config/ghostty/config.ghostty" 2>&1); then
    print_success "ghostty config is valid"
  else
    print_error "ghostty config is invalid: $GHOSTTY_OUT"
    ERRORS=$((ERRORS + 1))
  fi
else
  print_skip "ghostty not installed, skipping config validation"
fi

# Check Vim configuration
echo ""
print_info "Checking Vim configuration..."

if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
  print_success "vim-plug installed"
else
  print_error "vim-plug not installed"
  ERRORS=$((ERRORS + 1))
fi

# Check zsh configuration
echo ""
print_info "Checking zsh configuration..."

if [ -f "$HOME/.zshrc" ]; then
  print_success ".zshrc exists"
else
  print_error ".zshrc missing"
  ERRORS=$((ERRORS + 1))
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
  print_success "Oh My Zsh installed"
else
  print_error "Oh My Zsh not installed"
  ERRORS=$((ERRORS + 1))
fi

if grep -qF 'source "$DOTFILES_DIR/zsh/dotfiles.zsh"' "$HOME/.zshrc" 2>/dev/null; then
  print_success "dotfiles.zsh sourced in .zshrc"
else
  print_error "dotfiles.zsh not sourced in .zshrc"
  ERRORS=$((ERRORS + 1))
fi

if [ -f "$DOTFILES_DIR/zsh/config.zsh" ]; then
  print_success "zsh/config.zsh exists"
else
  print_error "zsh/config.zsh missing"
  ERRORS=$((ERRORS + 1))
fi

# Everything we need out of a real login shell, from one boot. Sourcing .zshrc
# loads the whole of oh-my-zsh and costs ~0.6s, and doing that once per variable
# was most of this script's runtime.
ZSH_PROBE=$(zsh -c 'source ~/.zshrc 2>/dev/null
  print -r -- "DOTFILES_DIR=$DOTFILES_DIR"
  print -r -- "ZSH_THEME=$ZSH_THEME"
  print -r -- "FZF_BASE=$FZF_BASE"
  print -r -- "SCMPUFF=$(whence -w scmpuff_status 2>/dev/null)"
  print -r -- "PATH=$PATH"' 2>/dev/null)

probe() { printf '%s\n' "$ZSH_PROBE" | sed -n "s/^$1=//p" | head -1; }

DOTFILES_DIR_CHECK=$(probe DOTFILES_DIR)
if [ -n "$DOTFILES_DIR_CHECK" ] && [ -d "$DOTFILES_DIR_CHECK" ]; then
  print_success "DOTFILES_DIR exported: $DOTFILES_DIR_CHECK"
else
  print_error "DOTFILES_DIR not properly exported"
  ERRORS=$((ERRORS + 1))
fi

# Check theme and configuration in a zsh subprocess
echo ""
print_info "Checking zsh theme and configuration..."

ZSH_THEME_CHECK=$(probe ZSH_THEME)
if [ "$ZSH_THEME_CHECK" = "tyom" ]; then
  print_success "ZSH_THEME is set to 'tyom'"
else
  print_error "ZSH_THEME is '$ZSH_THEME_CHECK' (expected 'tyom')"
  ERRORS=$((ERRORS + 1))
fi

# Check if FZF_BASE is set (only if fzf is installed)
if command -v fzf >/dev/null 2>&1; then
  FZF_BASE_CHECK=$(probe FZF_BASE)
  if [ -n "$FZF_BASE_CHECK" ]; then
    print_success "FZF_BASE is set: $FZF_BASE_CHECK"
  else
    print_error "FZF_BASE is not set"
    ERRORS=$((ERRORS + 1))
  fi
else
  print_skip "fzf not installed, skipping FZF_BASE check"
fi

# Check ~/bin is in PATH *ahead of* /usr/bin — appended entries never shadow
# system tools, which silently defeats the point of bin scripts
PATH_ENTRIES=$(probe PATH | tr ':' '\n')
HOME_BIN_POS=$(echo "$PATH_ENTRIES" | grep -n -x "$HOME/bin" | head -1 | cut -d: -f1)
USR_BIN_POS=$(echo "$PATH_ENTRIES" | grep -n -x "/usr/bin" | head -1 | cut -d: -f1)
if [ -z "$HOME_BIN_POS" ]; then
  print_error "$HOME/bin not in PATH"
  ERRORS=$((ERRORS + 1))
elif [ -n "$USR_BIN_POS" ] && [ "$HOME_BIN_POS" -gt "$USR_BIN_POS" ]; then
  print_error "$HOME/bin is in PATH but after /usr/bin (system tools shadow bin scripts)"
  ERRORS=$((ERRORS + 1))
else
  print_success "$HOME/bin is in PATH, ahead of /usr/bin"
fi

# Check scmpuff_status function exists (used by gs alias)
if probe SCMPUFF | grep -q "function"; then
  print_success "scmpuff_status function available"
else
  print_error "scmpuff_status function not available (gs alias will fail)"
  ERRORS=$((ERRORS + 1))
fi

# Check if fzf plugin is configured - only if fzf is installed
if command -v fzf >/dev/null 2>&1; then
  echo ""
  print_info "Checking fzf configuration..."

  if grep -q "plugins.*fzf" "$DOTFILES_DIR/zsh/config.zsh" 2>/dev/null ||
    grep -q 'plugins+=(fzf)' "$DOTFILES_DIR/zsh/config.zsh" 2>/dev/null; then
    print_success "fzf plugin configured"
  else
    print_error "fzf plugin not configured in zsh/config.zsh"
    ERRORS=$((ERRORS + 1))
  fi
else
  print_skip "fzf not installed, skipping fzf check"
fi

# Check bin scripts
echo ""
print_info "Checking bin scripts..."

for script in color-test gb git-author; do
  check_symlink "$HOME/bin/$script" "bin/$script"
done

# Check shell config files are sourceable
echo ""
print_info "Checking shell config files..."

for config in exports.sh aliases.sh functions.sh utils.sh; do
  if [ -f "$DOTFILES_DIR/shell/$config" ]; then
    print_success "shell/$config exists"
  else
    print_error "shell/$config missing"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check git configuration loads
echo ""
print_info "Checking git configuration..."

if git config --global --includes --get alias.s >/dev/null 2>&1; then
  print_success "Git aliases loaded"
else
  print_error "Git aliases not loaded"
  ERRORS=$((ERRORS + 1))
fi

if grep -qF "path = $DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig" 2>/dev/null; then
  print_success "Git dotfiles include configured"
else
  print_error "Git dotfiles include not configured in ~/.gitconfig"
  ERRORS=$((ERRORS + 1))
fi

# Check JS tooling
echo ""
print_info "Checking JS tooling..."

if command -v bun >/dev/null 2>&1; then
  print_success "Bun is installed ($(bun --version))"
else
  print_skip "Bun not installed (optional)"
fi

if command -v volta >/dev/null 2>&1; then
  print_success "Volta is installed ($(volta --version))"
  if command -v node >/dev/null 2>&1; then
    print_success "Node.js is installed ($(node --version))"
  else
    print_error "Node.js is not installed via Volta"
    print_info "Install with: volta install node"
    ERRORS=$((ERRORS + 1))
  fi
else
  print_error "Volta is not installed"
  print_info "Install with: curl -fsSL https://get.volta.sh | bash"
  ERRORS=$((ERRORS + 1))
fi

# Check Claude Code plugin
echo ""
print_info "Checking Claude Code plugin..."

# Whether the plugin's own code compiles is CI's job, and installing its
# dependencies is setup.sh's. All this needs to answer is whether the plugin is
# present and wired up.
PLUGIN_DIR="$DOTFILES_DIR/claude-plugin"
if [ -f "$PLUGIN_DIR/hooks/hooks.json" ]; then
  print_success "Claude Code plugin present"
  if [ -d "$PLUGIN_DIR/node_modules" ]; then
    print_success "Plugin dependencies installed"
  else
    print_warning "Plugin dependencies not installed (run: cd claude-plugin && bun install)"
  fi
else
  print_skip "Claude Code plugin not found, skipping"
fi

# Check Homebrew packages (optional - warnings only)
if command -v brew >/dev/null 2>&1; then
  echo ""
  print_info "Checking Homebrew packages (optional)..."

  for pkg in scmpuff bat git-delta herdr; do
    if brew list "$pkg" &>/dev/null; then
      print_success "$pkg installed"
    else
      print_warning "$pkg not installed (optional)"
    fi
  done
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
  print_success "All validation checks passed!"
  exit 0
else
  print_error "Validation failed with $ERRORS error(s)"
  exit 1
fi
