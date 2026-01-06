#!/bin/bash

# Validation script for dotfiles installation
# Checks that all symlinks and configurations are properly set up

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/shell/utils.sh"

ERRORS=0

print_step "Validating dotfiles installation..."

# Check symlinks exist
check_symlink() {
  local target="$1"
  local desc="$2"
  if [ -L "$target" ] || [ -f "$target" ]; then
    print_success "$desc exists"
  else
    print_error "$desc missing: $target"
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
check_symlink "$HOME/.oh-my-zsh/custom/themes/tyom.zsh-theme" "zsh theme"

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

DOTFILES_DIR_CHECK=$(zsh -c 'source ~/.zshrc 2>/dev/null; echo $DOTFILES_DIR')
if [ -n "$DOTFILES_DIR_CHECK" ] && [ -d "$DOTFILES_DIR_CHECK" ]; then
  print_success "DOTFILES_DIR exported: $DOTFILES_DIR_CHECK"
else
  print_error "DOTFILES_DIR not properly exported"
  ERRORS=$((ERRORS + 1))
fi

# Check theme and configuration in a zsh subprocess
echo ""
print_info "Checking zsh theme and configuration..."

ZSH_THEME_CHECK=$(zsh -c 'source ~/.zshrc 2>/dev/null; echo $ZSH_THEME')
if [ "$ZSH_THEME_CHECK" = "tyom" ]; then
  print_success "ZSH_THEME is set to 'tyom'"
else
  print_error "ZSH_THEME is '$ZSH_THEME_CHECK' (expected 'tyom')"
  ERRORS=$((ERRORS + 1))
fi

# Check if FZF_BASE is set (only if fzf is installed)
if command -v fzf >/dev/null 2>&1; then
  FZF_BASE_CHECK=$(zsh -c 'source ~/.zshrc 2>/dev/null; echo $FZF_BASE')
  if [ -n "$FZF_BASE_CHECK" ]; then
    print_success "FZF_BASE is set: $FZF_BASE_CHECK"
  else
    print_error "FZF_BASE is not set"
    ERRORS=$((ERRORS + 1))
  fi
else
  print_skip "fzf not installed, skipping FZF_BASE check"
fi

# Check if ~/bin is in PATH (where stow symlinks bin scripts)
HOME_BIN_CHECK=$(zsh -c 'source ~/.zshrc 2>/dev/null; echo $PATH' | grep -c "$HOME/bin" || true)
if [ "$HOME_BIN_CHECK" -gt 0 ]; then
  print_success "$HOME/bin is in PATH"
else
  print_error "$HOME/bin not in PATH"
  ERRORS=$((ERRORS + 1))
fi

# Check scmpuff_status function exists (used by gs alias)
SCMPUFF_CHECK=$(zsh -c 'source ~/.zshrc 2>/dev/null; type scmpuff_status' 2>&1)
if echo "$SCMPUFF_CHECK" | grep -q "function"; then
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

for script in color-test gb git-author ungit; do
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

PLUGIN_DIR="$DOTFILES_DIR/claude-plugin"
if [ -d "$PLUGIN_DIR" ] && [ -f "$PLUGIN_DIR/package.json" ]; then
  # Install dependencies if needed
  if [ ! -d "$PLUGIN_DIR/node_modules" ]; then
    print_info "Installing plugin dependencies..."
    INSTALL_SUCCESS=false
    if command -v bun >/dev/null 2>&1; then
      if (cd "$PLUGIN_DIR" && bun install --frozen-lockfile 2>/dev/null || bun install); then
        print_success "Dependencies installed with bun"
        INSTALL_SUCCESS=true
      else
        print_error "Failed to install dependencies with bun"
      fi
    fi
    if [ "$INSTALL_SUCCESS" = false ] && command -v npm >/dev/null 2>&1; then
      if (cd "$PLUGIN_DIR" && npm install); then
        print_success "Dependencies installed with npm"
        INSTALL_SUCCESS=true
      else
        print_error "Failed to install dependencies with npm"
      fi
    fi
  fi
  # Type check the plugin if dependencies are installed
  if [ -d "$PLUGIN_DIR/node_modules" ]; then
    if command -v bun >/dev/null 2>&1; then
      if (cd "$PLUGIN_DIR" && bun run tsc --noEmit 2>&1); then
        print_success "Claude Code plugin type check passed"
      else
        print_error "Claude Code plugin type check failed"
        ERRORS=$((ERRORS + 1))
      fi
    elif command -v npx >/dev/null 2>&1; then
      if (cd "$PLUGIN_DIR" && npx tsc --noEmit 2>&1); then
        print_success "Claude Code plugin type check passed"
      else
        print_error "Claude Code plugin type check failed"
        ERRORS=$((ERRORS + 1))
      fi
    else
      print_skip "No type checker available (bun/npx required)"
    fi
  fi
else
  print_skip "Claude Code plugin not found, skipping"
fi

# Check Homebrew packages (optional - warnings only)
if command -v brew >/dev/null 2>&1; then
  echo ""
  print_info "Checking Homebrew packages (optional)..."

  for pkg in scmpuff bat git-delta; do
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
