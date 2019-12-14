# TYOM ZSH Theme

if [[ $(whoami) == "root" ]]; then
  CARETCOLOR="red"
else
  CARETCOLOR="white"
fi

local _current_dir="%{$fg_bold[blue]%}%~%{$reset_color%} "

function _user_host {
  echo "%{$fg[green]%}%n%{$reset_color%} › $fg[yellow]%}%m%{$reset_color%}"
}

function _node_version {
  if [ -x "$(command -v node)" ]; then
    echo "%F{238}node $(node -v) ∘ npm $(npm -v)% %{$reset_color%}"
  fi
}

function _git_status {
  [ -f .git/REBASE_HEAD ] && echo "%{$fg[yellow]%}(REBASING)%{$reset_color%}"
  [ -f .git/MERGE_HEAD ] && echo "%{$fg[yellow]%}(MERGING)%{$reset_color%}"
  [ -f .git/BISECT_LOG ] && echo "%{$fg[yellow]%}(BISECTING)%{$reset_color%}"
}

PROMPT='
$(_user_host) ⫶ ${_current_dir}
%{$fg[$CARETCOLOR]%}❯%{$resetcolor%} '

if [[ "$(uname)" != "Darwin" ]]; then
  # Add additional spaces for Linux
  PROMPT+="    "
fi

RPROMPT='$(_node_version) $(_git_status) $(git_prompt_info)$(git_prompt_status)'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{187}Ⴤ%f %F{115}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"

ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%} +%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} –%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[yellow]%} ⋇%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[blue]%} ≈%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[cyan]%} ⊘%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[white]%} ∪%{$reset_color%}"

# STANDARD VARIABLES
# ================
# General
# -------
# %n - username
# %m - hostname (truncated to the first period)
# %M - hostname
# %l - the current tty
# %? - the return code of the last-run application
# %# - the prompt based on user privileges (# for root and % for the rest)
# %h or %! - current history event number
# %L - the current value of $SHLVL
#
# Time
# ----
# %t or %@ - 12-hour am/pm format
# %T - system time (HH:MM)
# %* - system time (HH:MM:SS)
#
# Date
# ----
# %w - date in day-dd format
# %W - date in mm/dd/yy format
# %D - date in yy-mm-dd format
# %{string} - date formatted using the strftime function (http://linux.die.net/man/3/strftime)
#
# Directories
# -----------
# %~ - current working directory ($HOME represented as ~)
# %d or %/ - current working directory
# %c or %. - trailing component of $PWD (for n trailing components put an integer n after %)
# %C - like %c or %. but $HOME is represented as ~)
#
# Misc
# ----
# %h or %! - current history event number
# %L - the current value of $SHLVL
#
# Formatting
# ----------
# %U[...]%u - begin and end underlined print
# %B[...]%b - begin and end bold print
# %{[...]%} - Begin and enter area that will not be printed. Useful for setting colors.
#
# Visual effects (wrap in %{...%} to make sure they are not printed e.g. %{%F{red}%}%~{%f%}
# --------------
# %B{...}%b - start/stop boldface mode
# %E        - clear the end of line
# %U{...}%u - start/stop underline mode
# %S{...}%s - start/stop standout mode
# %F{...}%f - start/stop foreground colour (keyword or colour code e.g. %F{red}%f or %F{196}%f
# %K{...}%k - start/stop background colour
# %{...%}   - literal escape sequence (doesn't change cursor position), can be nested
#
# More info: http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html
