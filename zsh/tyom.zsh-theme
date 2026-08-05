# TYOM ZSH Theme

if [[ $(whoami) == "root" ]]; then
  CARETCOLOR="red"
else
  CARETCOLOR="white"
fi

local _current_dir="%{$fg_bold[blue]%}%~%{$reset_color%} "

function _user_host {
  echo "%{$fg[green]%}%n%{$reset_color%} › %{$fg[yellow]%}%m%{$reset_color%}"
}

# `node -v` and `npm -v` cost ~130ms together, and RPROMPT ran both on every
# render. Volta swaps versions when you cd, so recompute then instead. A change
# made in place (`volta install node`) shows on the next cd rather than at once,
# which is the whole trade: a prompt that isn't 130ms slower every time.
function _set_node_version {
  _NODE_VERSION=""
  (( $+commands[node] )) || return
  _NODE_VERSION="%F{238}node $(node -v)"
  (( $+commands[npm] )) && _NODE_VERSION+=" ∘ npm $(npm -v)"
  _NODE_VERSION+="%f"
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _set_node_version
_set_node_version

function _prompt_git_state {
  [[ -d ".git/rebase-apply" || -d ".git/rebase-merge" ]] && echo "%{$fg[yellow]%}(REBASING)%{$reset_color%}"
  [ -f .git/MERGE_HEAD ] && echo "%{$fg[yellow]%}(MERGING)%{$reset_color%}"
  [ -f .git/BISECT_LOG ] && echo "%{$fg[yellow]%}(BISECTING)%{$reset_color%}"
}

# CONDA_ENV was a global set only while an env was active and never cleared, so
# the prompt kept showing the last one after `conda deactivate`. Local, and
# derived from CONDA_PREFIX each time.
function _conda_env_name {
  local env=""
  [[ -n $CONDA_PREFIX ]] && env="($CONDA_DEFAULT_ENV)"
  echo "%{$fg[cyan]%}$env%{$reset_color%}"
}

PROMPT='
$(_user_host) $(_conda_env_name) ${_current_dir}
%{$fg[$CARETCOLOR]%}❯%{$reset_color%} '

RPROMPT='${_NODE_VERSION} $(_prompt_git_state) $(git_prompt_info)$(git_prompt_status)'

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
# Prompt escapes: %n user, %m host, %~ cwd, %F{n} colour.
# Full list: https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html
