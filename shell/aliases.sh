alias l='ls'       # default
alias l.='ls -a'   # default + hidden
alias ll='ls -l'   # vertical
alias ll.='ls -al' # vertical + hidden

# git shortcuts
alias g="git"
alias gs="scmpuff_status"
alias d="git diff --color-words"
alias glg="gl --graph"
alias ga="git add"
alias gaa="git add --all"
alias gai="git add --patch"
alias gc="git commit"
alias gcf="git commit --fixup"
alias gca="git commit --amend"
alias gci="git ci"
# rebase
alias gri="git rebase -i"
alias grc="git rebase --continue"
alias gra="git rebase --abort"
alias gria="git rebase -i --autosquash"

# Docker
alias docker-rm-exited-containers="docker ps --filter status=dead --filter status=exited -aq | xargs docker rm -v"
docker-rm-unused-images() {
  local image
  docker images --filter dangling=true --quiet --no-trunc |
    while IFS= read -r image; do
      [ -n "$image" ] && docker rmi "$image"
    done
}
alias docker-rm-unused-volumes="docker volume ls -qf dangling=true | xargs docker volume rm"

# Run local server for current directory on port 8000
alias server="python3 -m http.server"

# Disk space
alias diskspace="df -P -kHl"

# Recursively delete `.DS_Store` files
alias cleanup_dsstore="find . -name '*.DS_Store' -type f -ls -delete"

# zshrc config
alias reload="source ~/.zshrc && echo 'Shell config reloaded from ~/.zshrc'"
