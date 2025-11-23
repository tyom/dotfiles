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

check_symlink "$HOME/.gitconfig" ".gitconfig"
check_symlink "$HOME/.gitignore" ".gitignore"
check_symlink "$HOME/.gitattributes" ".gitattributes"
check_symlink "$HOME/.vimrc" ".vimrc"
check_symlink "$HOME/.vimrc.bundles" ".vimrc.bundles"
check_symlink "$HOME/.oh-my-zsh/custom/themes/tyom.zsh-theme" "zsh theme"
check_symlink "$HOME/.dotfilesrc" ".dotfilesrc"

# Check zsh configuration
echo ""
print_info "Checking zsh configuration..."

if [ -f "$HOME/.zshrc" ]; then
  print_success ".zshrc exists"
else
  print_error ".zshrc missing"
  ERRORS=$((ERRORS + 1))
fi

if grep -qF 'source "$HOME/.dotfiles.zsh"' "$HOME/.zshrc" 2>/dev/null; then
  print_success "dotfiles.zsh sourced in .zshrc"
else
  print_error "dotfiles.zsh not sourced in .zshrc"
  ERRORS=$((ERRORS + 1))
fi

if [ -f "$HOME/.dotfiles.zsh" ]; then
  print_success ".dotfiles.zsh exists"
else
  print_error ".dotfiles.zsh missing"
  ERRORS=$((ERRORS + 1))
fi

if [ -f "$DOTFILES_DIR/zsh/config.zsh" ]; then
  print_success "zsh/config.zsh exists"
else
  print_error "zsh/config.zsh missing"
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
  print_info "fzf not installed, skipping FZF_BASE check"
fi

# Check if our PATH modifications are loaded
DOTFILES_BIN_CHECK=$(zsh -c 'source ~/.zshrc 2>/dev/null; echo $PATH' | grep -c "$DOTFILES_DIR/bin")
if [ "$DOTFILES_BIN_CHECK" -gt 0 ]; then
  print_success "DOTFILES_DIR/bin is in PATH"
else
  print_error "DOTFILES_DIR/bin not in PATH"
  ERRORS=$((ERRORS + 1))
fi

# Check if fzf plugin is configured - only if fzf is installed
if command -v fzf >/dev/null 2>&1; then
  echo ""
  print_info "Checking fzf configuration..."

  if grep -q "plugins.*fzf" "$DOTFILES_DIR/zsh/config.zsh" 2>/dev/null || \
     grep -q 'plugins+=(fzf)' "$DOTFILES_DIR/zsh/config.zsh" 2>/dev/null; then
    print_success "fzf plugin configured"
  else
    print_error "fzf plugin not configured in zsh/config.zsh"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo ""
  print_info "fzf not installed, skipping fzf check"
fi

# Check bin scripts
echo ""
print_info "Checking bin scripts..."

for script in color-test gb git-author icat ils; do
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

if git config --global --get alias.s >/dev/null 2>&1; then
  print_success "Git aliases configured"
else
  print_error "Git aliases not loaded"
  ERRORS=$((ERRORS + 1))
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
