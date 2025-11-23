# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Configure oh-my-zsh theme
ZSH_THEME="tyom"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Tab completion fix for 'cd ..<TAB>'
zstyle ':completion:*' special-dirs true

# Append history as commands are executed
setopt inc_append_history

# # Disable sharing history between tabs (sessions)
unsetopt share_history

# # Avoid duplicates
setopt hist_ignore_all_dups # Don't save duplicates

# # Expansion and Globbing
# # treat #, ~, and ^ as part of patterns for filename generation
setopt extended_glob
