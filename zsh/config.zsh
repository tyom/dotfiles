# Dotfiles ZSH Configuration
# This file is sourced from ~/.zshrc BEFORE oh-my-zsh

# Ensure DOTFILES_DIR is set
if [ -z "$DOTFILES_DIR" ]; then
  echo "\e[0;31m ✖ \$DOTFILES_DIR is not set. Source ~/.dotfilesrc first.\e[0m\n"
  return
fi

# Source shell modules (PATH, aliases, functions)
source $DOTFILES_DIR/shell/utils.sh
source $DOTFILES_DIR/shell/exports.sh
source $DOTFILES_DIR/shell/aliases.sh
source $DOTFILES_DIR/shell/functions.sh

# Disable partial line marker (%) for commands without trailing newline
PROMPT_EOL_MARK=''

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Tab completion fix for 'cd ..<TAB>'
zstyle ':completion:*' special-dirs true

# Append history as commands are executed
setopt inc_append_history

# Disable sharing history between tabs (sessions)
unsetopt share_history

# Avoid duplicates
setopt hist_ignore_all_dups

# Expansion and Globbing
# treat #, ~, and ^ as part of patterns for filename generation
setopt extended_glob

# Set FZF_BASE for oh-my-zsh fzf plugin (must be set BEFORE oh-my-zsh loads)
if exists brew; then
  FZF_BREW_PATH="$(brew --prefix)/opt/fzf"
  [ -d "$FZF_BREW_PATH" ] && export FZF_BASE="$FZF_BREW_PATH"
fi

# Set plugins array (must be set BEFORE oh-my-zsh loads)
# Note: 'git' plugin excluded to use custom aliases from shell/aliases.sh
plugins=(z colored-man-pages docker npm extract gh)

# Only add fzf plugin if fzf is installed
[ -n "$FZF_BASE" ] && plugins+=(fzf)

# Note: oh-my-zsh will be sourced by ~/.zshrc after this file
