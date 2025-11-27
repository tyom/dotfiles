# Defaults
: ${YES_OVERRIDE:=false}
: ${DOTFILES_DIR:="$(cd $(dirname "$0")/.. && pwd)"}

# Stow packages to install (directories in the repo root)
STOW_PACKAGES=(git vim oh-my-zsh bin claude-code)
